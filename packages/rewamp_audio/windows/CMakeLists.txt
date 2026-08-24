cmake_minimum_required(VERSION 3.14)

set(PLUGIN_NAME "rewamp_audio")

set(REWAMP_WITH_VGM ON CACHE BOOL "" FORCE)
include("${CMAKE_CURRENT_SOURCE_DIR}/../cmake/rewamp.cmake")

add_library(${PLUGIN_NAME} SHARED ${REWAMP_CORE_SOURCES})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
rewamp_configure_decoders(${PLUGIN_NAME})

# miniaudio on Windows uses WinMM / WASAPI — no extra link needed
target_link_libraries(${PLUGIN_NAME} PRIVATE ole32 uuid)
