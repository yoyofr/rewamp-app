// Pont visualiseurs ↔ Flutter pour Windows.
// Parallèle de linux/rewamp_audio_plugin.cc.
//
// Ce fichier ne contient QUE ce qui exige les en-têtes de l'embedder: la
// texture Flutter et l'installation du vtable. Toute la logique (modes,
// register, notify, cycle de vie) vit dans le MOTEUR — voir
// src/windows/rewamp_viz_windows.h: Dart ouvre rewamp_audio.dll et c'est là
// qu'il cherche les symboles, alors que seul un vrai greffon de plateforme
// reçoit un registre de textures.
//
// Le moteur rend hors écran dans SON contexte ANGLE et publie chaque image
// comme texture Direct3D 11 partagée; l'embedder ouvre son handle DXGI dans
// son propre périphérique. Zéro copie. En mode PIXELS (repli), l'image est
// relue sur le processeur et remise comme tampon RGBA.

#include "include/rewamp_audio/rewamp_audio_plugin.h"

#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <memory>
#include <stdio.h>
#include <stdlib.h>

// REWAMP_WINDOWS_VIZ=0 (windows/CMakeLists.txt): le moteur n'a ni ANGLE ni
// renderers, donc pas de pont à brancher — mais le registrant généré appelle
// quand même notre fonction d'enregistrement, qui doit exister.
#ifndef REWAMP_WINDOWS_VIZ

void RewampAudioPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef) {
  fprintf(stderr, "[rewamp_viz] build sans visualiseurs (REWAMP_WINDOWS_VIZ=0)\n");
}

#else

#include "../src/windows/rewamp_viz_windows.h"

namespace {

flutter::TextureRegistrar*               g_registrar = nullptr;
std::unique_ptr<flutter::TextureVariant> g_texture;
int64_t                                  g_texture_id = -1;

// Les descripteurs rendus à l'embedder doivent rester valides jusqu'à son
// prochain appel: ils vivent donc ici, pas sur la pile du rappel.
FlutterDesktopGpuSurfaceDescriptor g_gpu_desc = {};
FlutterDesktopPixelBuffer          g_px_desc  = {};
uint8_t*                           g_px_buf   = nullptr;
size_t                             g_px_cap   = 0;

// Fil de rastérisation. Rendre nullptr = « pas d'image cette fois »: Flutter
// garde la précédente.
const FlutterDesktopGpuSurfaceDescriptor* ObtainGpuSurface(size_t, size_t) {
  int w = 0, h = 0;
  void* handle = rewamp_gl_windows_front_handle(&w, &h);
  if (!handle || w <= 0 || h <= 0) return nullptr;

  static bool announced = false;
  if (!announced) {
    announced = true;
    fprintf(stderr, "[rewamp_viz] texture D3D partagée consommée par Flutter (%dx%d)\n", w, h);
  }
  g_gpu_desc.struct_size    = sizeof(FlutterDesktopGpuSurfaceDescriptor);
  g_gpu_desc.handle         = handle;
  g_gpu_desc.width          = g_gpu_desc.visible_width  = (size_t)w;
  g_gpu_desc.height         = g_gpu_desc.visible_height = (size_t)h;
  // Un pbuffer ANGLE/D3D11 est une texture DXGI_FORMAT_B8G8R8A8_UNORM.
  g_gpu_desc.format           = kFlutterDesktopPixelFormatBGRA8888;
  g_gpu_desc.release_callback = nullptr;
  g_gpu_desc.release_context  = nullptr;
  return &g_gpu_desc;
}

const FlutterDesktopPixelBuffer* CopyPixels(size_t, size_t) {
  int w = 0, h = 0;
  if (!rewamp_gl_windows_copy_front_pixels(&g_px_buf, &g_px_cap, &w, &h)) return nullptr;

  static bool announced = false;
  if (!announced) {
    announced = true;
    fprintf(stderr, "[rewamp_viz] mode PIXELS: image relue consommée par Flutter (%dx%d)\n", w, h);
  }
  g_px_desc.buffer           = g_px_buf;
  g_px_desc.width            = (size_t)w;
  g_px_desc.height           = (size_t)h;
  g_px_desc.release_callback = nullptr;
  g_px_desc.release_context  = nullptr;
  return &g_px_desc;
}

// ── Vtable remis au moteur ──────────────────────────────────────────────────
int64_t OpsCreate(void*) {
  if (!g_registrar) return -1;
  if (rewamp_gl_windows_pixel_mode()) {
    g_texture = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture(CopyPixels));
  } else {
    g_texture = std::make_unique<flutter::TextureVariant>(
        flutter::GpuSurfaceTexture(kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
                                   ObtainGpuSurface));
  }
  g_texture_id = g_registrar->RegisterTexture(g_texture.get());
  if (g_texture_id < 0) { g_texture.reset(); return -2; }
  return g_texture_id;
}

void OpsMark(void*) {
  if (g_registrar && g_texture_id >= 0)
    g_registrar->MarkTextureFrameAvailable(g_texture_id);
}

void OpsDestroy(void*) {
  if (g_registrar && g_texture_id >= 0) {
    // La variante à rappel: l'objet texture doit survivre jusqu'à ce que le
    // fil de rastérisation ait fini de s'en servir.
    auto* dying = g_texture.release();
    g_registrar->UnregisterTexture(g_texture_id, [dying]() { delete dying; });
  }
  g_texture.reset();
  g_texture_id = -1;
}

}  // namespace

void RewampAudioPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  auto* reg = flutter::PluginRegistrarManager::GetInstance()
                  ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  g_registrar = reg ? reg->texture_registrar() : nullptr;
  if (!g_registrar) {
    fprintf(stderr, "[rewamp_viz] pas de registre de textures — visualiseurs inactifs\n");
    return;
  }

  // REWAMP_VIZ_PIXEL_MODE=1 force la relecture CPU: porte de secours si le
  // partage Direct3D ne passe pas sur une machine (deux adaptateurs
  // graphiques), et seul moyen de comparer les deux chemins.
  if (const char* force = getenv("REWAMP_VIZ_PIXEL_MODE")) {
    if (force[0] == '1') {
      rewamp_gl_windows_set_pixel_mode(1);
      fprintf(stderr, "[rewamp_viz] visualiseurs en mode PIXELS (relecture CPU)\n");
    }
  }

  static const RewampWinTextureOps ops = {nullptr, OpsCreate, OpsMark, OpsDestroy};
  rewamp_viz_windows_set_texture_ops(&ops);
}

#endif  // REWAMP_WINDOWS_VIZ
