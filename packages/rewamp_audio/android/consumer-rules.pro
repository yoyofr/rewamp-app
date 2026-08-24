# RewampAudioPlugin's companion methods (jniCreateTexture, jniDestroyTexture,
# startAudioService, stopAudioService) are called FROM C++ via JNI — R8 sees no
# Java references and strips/renames them in release builds, which broke the
# GPU visualizer path (GetStaticMethodID → "method not found", id=-3). Keep the
# whole plugin class + companion so JNI lookups keep working.
-keep class com.modizer.rewamp.rewamp_audio.RewampAudioPlugin { *; }
-keep class com.modizer.rewamp.rewamp_audio.RewampAudioPlugin$Companion { *; }
