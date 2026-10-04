# Triplet vcpkg de rewamp pour ANGLE — voir scripts/build_angle_windows.ps1.
#
# ⚠️ Le port vcpkg bâtit ANGLE par les CMake de WebKit, qui OUBLIENT deux
# définitions que la build GN autonome d'ANGLE pose d'office (BUILD.gn,
# `internal_config`: angle_enable_share_context_lock = !build_with_chromium,
# angle_enable_context_mutex = true). Sans elles, deux contextes d'un même
# groupe de partage utilisés depuis deux fils ne sont PAS sérialisés — « the
# client need to use gl calls in a threadsafe way », dit le commentaire
# d'ANGLE — et c'est exactement ce que fait le préchargeur de projectM.
# Les poser ici les donne à TOUTES les sources du port, ce qui est sans effet
# hors d'ANGLE.
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
# Seule la release est embarquée: la debug doublait le temps de build pour rien.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_C_FLAGS   "/DANGLE_ENABLE_SHARE_CONTEXT_LOCK=1 /DANGLE_ENABLE_CONTEXT_MUTEX=1")
set(VCPKG_CXX_FLAGS "/DANGLE_ENABLE_SHARE_CONTEXT_LOCK=1 /DANGLE_ENABLE_CONTEXT_MUTEX=1")
