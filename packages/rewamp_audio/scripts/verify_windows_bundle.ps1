# Vérifie un dossier de build Windows (runner\Release ou runner\Debug) AVANT de
# le distribuer: ce qui a ATTERRI, pas ce que la recette promettait.
#
# Deux pièges qu'une build verte ne montre pas (docs/BUILD_WINDOWS.md §5.7):
#   * une DLL CONSTRUITE mais jamais copiée à côté de rewamp.exe — l'app meurt
#     au démarrage sur un DynamicLibrary.open introuvable;
#   * une dépendance tirée en douce (une DLL de vcpkg, un runtime DEBUG) qui
#     n'existe pas chez l'utilisateur.
#
# Donc: les fichiers attendus sont là, et CHAQUE dépendance de CHAQUE binaire du
# dossier est soit livrée dans le dossier, soit une DLL du système. Lu au
# `dumpbin /dependents`, sur l'artefact.
#
# Usage: powershell -File verify_windows_bundle.ps1 <dossier> [-Release]
param(
  [Parameter(Mandatory)] [string]$Dir,
  [switch]$Release
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Dir)) { throw "dossier introuvable: $Dir" }

$fail = @()

# ── Les fichiers attendus ────────────────────────────────────────────────────
$expected = @('rewamp.exe', 'flutter_windows.dll', 'rewamp_audio.dll',
              'rewamp_audio_plugin.dll', 'libEGL.dll', 'libGLESv2.dll',
              'data\icudtl.dat', 'data\flutter_assets\AssetManifest.bin')
# Le code Dart compilé AOT n'existe qu'en release (en debug, c'est le kernel).
if ($Release) { $expected += 'data\app.so' }
foreach ($e in $expected) {
  if (-not (Test-Path (Join-Path $Dir $e))) { $fail += "absent: $e" }
}
# FFmpeg (vgmstream): un jeu complet, quelle que soit sa version de SONAME.
foreach ($ff in 'avcodec', 'avformat', 'avutil', 'swresample') {
  if (-not (Get-ChildItem $Dir -Filter "$ff-*.dll" -ErrorAction SilentlyContinue)) {
    $fail += "absent: $ff-*.dll (FFmpeg de vgmstream)"
  }
}

# ── Les dépendances de chaque binaire ────────────────────────────────────────
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -property installationPath
$dumpbin = Get-ChildItem "$vs\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe" |
  Select-Object -Last 1 -ExpandProperty FullName
if (-not $dumpbin) { throw "dumpbin introuvable (Visual Studio: $vs)" }

$here = @{}
Get-ChildItem $Dir -File | ForEach-Object { $here[$_.Name.ToLowerInvariant()] = $true }

# DLL du système: présentes sur tout Windows 10/11, jamais à livrer.
$system = '^(kernel32|user32|gdi32|advapi32|shell32|shlwapi|ole32|oleaut32|' +
          'comdlg32|comctl32|ws2_32|winmm|imm32|version|setupapi|bcrypt|ncrypt|' +
          'crypt32|secur32|psapi|dbghelp|dwmapi|uxtheme|d3d9|d3d11|d3d12|' +
          'dxgi|dxguid|d3dcompiler_47|opengl32|mfplat|mf|mfreadwrite|' +
          'propsys|powrprof|winhttp|wininet|userenv|iphlpapi|dnsapi|' +
          'mmdevapi|avrt|ksuser|uiautomationcore|windowscodecs|dwrite|' +
          'd2d1|shcore|wtsapi32|netapi32|rpcrt4|combase|ntdll|' +
          'normaliz|urlmon|hid|cfgmgr32|msimg32|winspool\.drv|oleacc|dsound|' +
          'api-ms-win-.*|ext-ms-win-.*)\.dll$'
# Le runtime C++ de Visual Studio: PAS sur un Windows neuf. Toléré ici à
# condition d'être livré dans le dossier (déploiement app-local) — sinon il
# faut le Visual C++ Redistributable chez l'utilisateur.
$vcrt = '^(vcruntime140|vcruntime140_1|msvcp140|msvcp140_1|msvcp140_2|' +
        'msvcp140_atomic_wait|concrt140|vccorlib140)\.dll$'
$vcrtDebug = '^(vcruntime140d|vcruntime140_1d|msvcp140d|msvcp140_1d|' +
             'msvcp140_2d|ucrtbased|concrt140d)\.dll$'

# Exceptions NOMMÉES, une par une, avec leur raison.
#   dartjni.dll -> jvm.dll: le paquet Dart `jni` (transitif) est le pont Java
#   d'ANDROID. Flutter copie sa DLL dans tout bundle Windows, mais rien ne la
#   CHARGE ici (l'app tourne sans Java) — sa dépendance à jvm.dll ne joue pas.
$known = @{ 'dartjni.dll' = @('jvm.dll') }

$needVcrt = @{}
foreach ($bin in Get-ChildItem -Path "$Dir\*" -File -Include *.dll, *.exe) {
  $deps = & $dumpbin /nologo /dependents $bin.FullName |
    Where-Object { $_ -match '^\s+\S+\.(dll|drv)\s*$' } | ForEach-Object { $_.Trim() }
  foreach ($d in $deps) {
    $k = $d.ToLowerInvariant()
    if ($here.ContainsKey($k)) { continue }
    if ($k -match $system) { continue }
    $exc = $known[$bin.Name.ToLowerInvariant()]
    if ($exc -and ($exc -contains $k)) { continue }
    if ($k -match $vcrtDebug) {
      if ($Release) { $fail += "$($bin.Name) -> $d (runtime DEBUG dans une release)" }
      continue
    }
    if ($k -match $vcrt) { $needVcrt[$k] = $true; continue }
    $fail += "$($bin.Name) -> $d (ni livrée, ni système)"
  }
}

if ($needVcrt.Count) {
  "runtime Visual C++ requis et NON livré: $(($needVcrt.Keys | Sort-Object) -join ', ')"
  "  -> l'utilisateur doit avoir le Visual C++ Redistributable x64."
}
if ($fail.Count) {
  $fail | ForEach-Object { "  ✗ $_" }
  throw "$($fail.Count) problème(s) dans $Dir"
}
$n = (Get-ChildItem $Dir -File).Count
"OK: $Dir — $n fichiers à la racine, dépendances résolues"
