cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")
# Version de pubspec.yaml (generated_config.cmake), pour `rewamp --version`.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")

# Add dependency libraries. Add any application-specific dependencies here.
# ⚠️ libgcc_s EN TÊTE des dépendances, AVANT libflutter_linux_gtk.so.
# Depuis Flutter 3.50 l'embarqué Linux EXPORTE l'unwinder de LLVM
# (_Unwind_RaiseException, _Unwind_Resume…; absent de la 3.47.5, vérifié par
# `nm -D` sur les deux artefacts). La résolution des symboles suit l'ordre des
# NEEDED de l'exécutable: libflutter venait avant libgcc_s (tirée seulement par
# libstdc++), donc TOUT `throw` du processus — greffons, moteur, libopenmpt —
# partait dans l'unwinder de Flutter, incompatible avec libstdc++, et chaque
# exception, même rattrapée juste en dessous, devenait « terminate called after
# throwing an instance of … » (LibsecretError au lancement sans trousseau,
# openmpt::exception à l'ouverture d'un morceau; 2026-11-17). Lié ici en premier
# et sans --as-needed, libgcc_s.so.1 est la première à fournir ces symboles.
# Oracle: REWAMP_SELFTEST_EH=1 (main.cc), lancé par la CI de l'AppImage.
target_link_libraries(${BINARY_NAME} PRIVATE "-Wl,--push-state,--no-as-needed" gcc_s "-Wl,--pop-state")
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
