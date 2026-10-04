# Construit ANGLE (OpenGL ES 3.0 -> Direct3D 11) pour Windows x64.
# Sortie: windows/Libs/angle/{bin/{libEGL,libGLESv2}.dll, lib/*.lib, include/}
#         (lu par windows/CMakeLists.txt; tout Libs/ est ignoré par git, donc
#          à lancer UNE fois par checkout — même règle que macOS et iOS).
#
# Pourquoi un ANGLE à nous alors que Flutter en embarque un: celui du moteur
# est lié STATIQUEMENT dans flutter_windows.dll, qui n'exporte aucun symbole
# egl*/gl* (vérifié au dumpbin). On ne peut pas s'en servir.
#
# Pourquoi vcpkg et pas depot_tools comme scripts/build_angle_macos.sh: le
# port vcpkg bâtit ANGLE par CMake, sans le checkout Chromium de ~10 Go, et le
# vcpkg livré avec Visual Studio suffit (rien à installer). Contrepartie: on
# prend ANGLE au commit que le REGISTRE vcpkg épingle (`builtin-baseline` de
# windows/angle/vcpkg.json), pas à patches/angle/UPSTREAM_COMMIT, et sans le
# patch Metal — qui ne concerne que le backend d'Apple.
#
# Les arbres de build (plusieurs Go) vivent HORS du dépôt, sous $Work.
param(
  [string]$Work = $(if ($env:ANGLE_WORK_DIR) { $env:ANGLE_WORK_DIR } else { 'I:\Dev\angle-build-windows' }),
  [int]$Jobs = 6
)
$ErrorActionPreference = 'Stop'

$pkg      = Split-Path $PSScriptRoot
$manifest = Join-Path $pkg 'windows\angle'
$out      = Join-Path $pkg 'windows\Libs\angle'
# Triplet À NOUS (windows/angle/triplets): il pose les verrous de contexte
# qu'ANGLE active d'office en build autonome et que la build CMake du port
# oublie — sans eux, le préchargeur de projectM fait planter le pilote D3D11.
$triplet  = 'x64-windows-rewamp'
$overlay  = Join-Path $manifest 'triplets'
# Port À NOUS aussi (windows/angle/ports/angle): celui du registre, à la
# baseline épinglée, PLUS 900-rewamp-wgl-context-virtualization.patch — sans
# lui, le backend OpenGL d'ANGLE refuse un second contexte sur un autre fil,
# le préchargeur de projectM meurt et chaque changement de preset gèle
# l'image (BUILD_WINDOWS.md §6.2). Pour suivre une nouvelle baseline: recopier
# le port du registre et ré-appliquer le patch.
$ports    = Join-Path $manifest 'ports'

# Le vcpkg de Visual Studio n'est pas dans le PATH; vswhere donne l'installation.
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
# cl.exe en parallèle sature vite la mémoire sur une machine de 16 Go.
$env:VCPKG_MAX_CONCURRENCY = "$Jobs"

& $vcpkg install `
  "--triplet=$triplet" `
  "--overlay-triplets=$overlay" `
  "--overlay-ports=$ports" `
  "--x-manifest-root=$manifest" `
  "--x-install-root=$Work\installed" `
  "--x-buildtrees-root=$Work\buildtrees" `
  "--x-packages-root=$Work\packages" `
  "--downloads-root=$Work\downloads"
if ($LASTEXITCODE -ne 0) { throw "vcpkg install a échoué ($LASTEXITCODE)" }

$inst = Join-Path $Work "installed\$triplet"
foreach ($d in 'bin','lib','include') { New-Item -ItemType Directory -Force (Join-Path $out $d) | Out-Null }
Copy-Item "$inst\bin\libEGL.dll","$inst\bin\libGLESv2.dll" (Join-Path $out 'bin') -Force
Copy-Item "$inst\lib\libEGL.lib","$inst\lib\libGLESv2.lib" (Join-Path $out 'lib') -Force
foreach ($h in 'EGL','GLES2','GLES3','KHR') {
  Copy-Item (Join-Path $inst "include\$h") (Join-Path $out 'include') -Recurse -Force
}
# Les dépendances d'exécution d'ANGLE (zlib…) atterrissent aussi dans bin/:
# on les prend toutes, le contrôle se fait au dumpbin /dependents.
Get-ChildItem "$inst\bin" -Filter *.dll | Where-Object { $_.Name -notmatch '^lib(EGL|GLESv2)\.dll$' } |
  ForEach-Object { Copy-Item $_.FullName (Join-Path $out 'bin') -Force }

"--- sortie ---"
Get-ChildItem $out -Recurse -File -Include *.dll,*.lib | ForEach-Object { "{0,10:N0}  {1}" -f $_.Length, $_.FullName.Replace("$out\",'') }
