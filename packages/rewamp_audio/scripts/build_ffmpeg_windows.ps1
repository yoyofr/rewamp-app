# Construit un FFmpeg MINIMAL pour le vgmstream de rewamp sous Windows x64.
# Sortie: windows/Libs/ffmpeg/{bin/*.dll, lib/*.lib, include/}
#         (lue par windows/CMakeLists.txt; tout Libs/ est ignoré par git, donc
#          à lancer UNE fois par checkout, comme build_angle_windows.ps1).
#
# Pourquoi: sans FFmpeg, vgmstream se construit quand même et les formats qui
# passent par ffmpeg_decoder.c (Vorbis, Opus, AAC, ATRAC3, WMA, XMA…) échouent
# seulement à la LECTURE, fichier par fichier. Android a son ffmpeg-kit vendoré,
# l'AppImage son build minimal (scripts/appimage/build_ffmpeg_minimal.sh);
# Windows n'avait rien.
#
# Même parti que l'AppImage: le port vcpkg configure avec `--disable-autodetect`
# (aucune bibliothèque externe) et en LGPL, et on ne demande que les trois
# bibliothèques que ffmpeg_decoder.c inclut (avcodec, avformat, swresample;
# avutil vient avec). Les décodeurs NATIFS de FFmpeg couvrent tout ce que
# vgmstream lui demande.
#
# Même outillage qu'ANGLE: le vcpkg livré avec Visual Studio, rien à installer.
# Le port télécharge lui-même un MSYS2 pour lancer le `configure` de FFmpeg.
# Les arbres de build vivent HORS du dépôt, sous $Work.
param(
  [string]$Work = $(if ($env:FFMPEG_WORK_DIR) { $env:FFMPEG_WORK_DIR } else { 'I:\Dev\ffmpeg-build-windows' }),
  [int]$Jobs = 6
)
$ErrorActionPreference = 'Stop'

$pkg      = Split-Path $PSScriptRoot
$manifest = Join-Path $pkg 'windows\ffmpeg'
$out      = Join-Path $pkg 'windows\Libs\ffmpeg'
$triplet  = 'x64-windows-rewamp-ffmpeg'
$overlay  = Join-Path $manifest 'triplets'

# VCPKG_EXE impose un vcpkg précis — la CI s'en sert: le `C:\vcpkg` du runner
# peut ne pas contenir le commit épinglé par `builtin-baseline`.
$vcpkg = $env:VCPKG_EXE
if (-not $vcpkg) { $vcpkg = (Get-Command vcpkg -ErrorAction SilentlyContinue).Source }
if (-not $vcpkg) {
  $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  $vs = & $vswhere -latest -products * -property installationPath
  $vcpkg = Join-Path $vs 'VC\vcpkg\vcpkg.exe'
}
if (-not (Test-Path $vcpkg)) { throw "vcpkg introuvable (cherché: $vcpkg)" }
"vcpkg: $vcpkg"

New-Item -ItemType Directory -Force $Work | Out-Null
$env:VCPKG_MAX_CONCURRENCY = "$Jobs"

& $vcpkg install `
  "--triplet=$triplet" `
  "--overlay-triplets=$overlay" `
  "--x-manifest-root=$manifest" `
  "--x-install-root=$Work\installed" `
  "--x-buildtrees-root=$Work\buildtrees" `
  "--x-packages-root=$Work\packages" `
  "--downloads-root=$Work\downloads"
if ($LASTEXITCODE -ne 0) { throw "vcpkg install a échoué ($LASTEXITCODE)" }

$inst = Join-Path $Work "installed\$triplet"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
foreach ($d in 'bin','lib','include') { New-Item -ItemType Directory -Force (Join-Path $out $d) | Out-Null }
foreach ($l in 'avcodec','avformat','avutil','swresample') {
  Copy-Item "$inst\lib\$l.lib" (Join-Path $out 'lib') -Force
  Copy-Item (Join-Path $inst "include\lib$l") (Join-Path $out 'include') -Recurse -Force
}
Get-ChildItem "$inst\bin" -Filter *.dll | ForEach-Object { Copy-Item $_.FullName (Join-Path $out 'bin') -Force }

# ── Contrôle sur l'ARTEFACT: aucune dépendance hors système et FFmpeg ───────
# Même principe que build_ffmpeg_minimal.sh: on vérifie ce qui a été produit,
# pas les drapeaux qu'on a cru passer.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -property installationPath
$dumpbin = Get-ChildItem "$vs\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe" | Select-Object -Last 1 -ExpandProperty FullName
$foreign = @()
foreach ($dll in Get-ChildItem (Join-Path $out 'bin') -Filter *.dll) {
  $deps = & $dumpbin /nologo /dependents $dll.FullName | Where-Object { $_ -match '^\s+\S+\.dll\s*$' } | ForEach-Object { $_.Trim() }
  foreach ($d in $deps) {
    if ($d -match '^(av|sw)[a-z]+-\d+\.dll$') { continue }
    # ncrypt/crypt32: le TLS Schannel d'avformat — des DLL du SYSTÈME, présentes
    # partout, pas une bibliothèque à embarquer.
    if ($d -match '^(?i)(kernel32|user32|advapi32|bcrypt|ncrypt|crypt32|ole32|shell32|ws2_32|secur32|psapi|vcruntime140(_1)?|msvcp140|ucrtbase)\.dll$') { continue }
    if ($d -match '^(?i)api-ms-win-') { continue }
    $foreign += "$($dll.Name) -> $d"
  }
}
if ($foreign.Count) { $foreign | ForEach-Object { "    $_" }; throw "$($foreign.Count) dépendance(s) inattendue(s)" }
"dépendances: système et FFmpeg seulement"

"--- sortie ---"
Get-ChildItem $out -Recurse -File -Include *.dll,*.lib | ForEach-Object { "{0,12:N0}  {1}" -f $_.Length, $_.FullName.Replace("$out\",'') }
