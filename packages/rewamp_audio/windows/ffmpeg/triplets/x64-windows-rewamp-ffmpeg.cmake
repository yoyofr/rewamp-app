# Triplet vcpkg de rewamp pour FFmpeg — voir scripts/build_ffmpeg_windows.ps1.
# DLL (FFmpeg est LGPL: on le redistribue en bibliothèques dynamiques,
# remplaçables, comme sur Android et dans l'AppImage), CRT dynamique, release
# seulement.
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_BUILD_TYPE release)
