# rewamp vendoring shim.
#
# Upstream projectM ships a GenerateShaderResources.cmake that embeds the
# TransitionShaders/*.frag|.vert files into BuiltInTransitionsResources.hpp at
# configure time (via a bin2c-style helper). Modizer's vendored tree did NOT
# carry that module, but it DID commit the fully-generated output header
# (src/libprojectM/Renderer/BuiltInTransitionsResources.hpp, 9 shader string
# constants). So instead of re-implementing the generator we simply publish the
# pre-committed header to the expected binary-dir location.
#
# If a newer upstream is ever re-vendored, restore the real module + .frag
# regeneration; the committed header must stay in sync with TransitionShaders/.

function(generate_shader_resources OUTPUT)
    # OUTPUT == ${CMAKE_CURRENT_BINARY_DIR}/BuiltInTransitionsResources.hpp
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/BuiltInTransitionsResources.hpp"
        "${OUTPUT}"
        COPYONLY)
endfunction()
