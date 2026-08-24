// Unity build of the rewamp_audio core C sources for the CocoaPods target.
// CocoaPods compiles files under Classes/, so we re-include the shared sources
// from ../src via relative includes. The miniaudio *implementation* is compiled
// separately as Objective-C in miniaudio_impl.m (it pulls in AVFoundation).
#include "../../src/rewamp_audio.c"
#include "../../src/rewamp_assets.c"
#include "../../src/rewamp_registry.c"
#include "../../src/rewamp_datasource.c"
#include "../../src/rewamp_extract.c"
#include "../../src/rewamp_tags.c"    // ID3/Vorbis/RIFF tag reader (miniaudio fallback)
#include "../../src/rewamp_notes.c"
#include "../../src/rewamp_pattern.c"  // tracker-pattern viz cursor store

#ifdef REWAMP_WITH_OPENMPT
#include "../../src/rewamp_plugin_openmpt.c"
#endif
