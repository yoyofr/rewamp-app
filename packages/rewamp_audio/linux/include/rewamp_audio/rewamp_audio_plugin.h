// Plugin GTK de rewamp_audio pour Linux de bureau.
//
// Sa SEULE raison d'être est l'accès au FlTextureRegistrar: le moteur est un
// plugin FFI (Dart ouvre librewamp_audio.so directement), mais publier une
// texture GL à Flutter demande le registrar, qui n'est remis qu'à un vrai
// plugin de plateforme. C'est l'équivalent Linux de
// src/apple/rewamp_viz_plugin.mm.
#ifndef REWAMP_AUDIO_PLUGIN_H
#define REWAMP_AUDIO_PLUGIN_H

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

FLUTTER_PLUGIN_EXPORT void rewamp_audio_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // REWAMP_AUDIO_PLUGIN_H
