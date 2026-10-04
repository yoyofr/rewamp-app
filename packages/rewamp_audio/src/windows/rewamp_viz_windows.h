// Pont entre le MOTEUR (rewamp_audio.dll, que Dart ouvre en FFI) et le greffon
// Windows (rewamp_audio_plugin.dll, le seul à qui l'embedder remet un registre
// de textures). Même découpage que Linux, pour la même raison — voir
// src/linux/rewamp_viz_linux.h. Rien ici n'est de l'API FFI: Dart n'y touche
// jamais.
#ifndef REWAMP_VIZ_WINDOWS_H
#define REWAMP_VIZ_WINDOWS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Deux DLL: le moteur EXPORTE ces symboles, le greffon les IMPORTE.
// REWAMP_ENGINE_IMPL est posé sur la cible du moteur (windows/CMakeLists.txt).
#ifdef REWAMP_ENGINE_IMPL
#  define REWAMP_VIZ_WIN_API __declspec(dllexport)
#else
#  define REWAMP_VIZ_WIN_API __declspec(dllimport)
#endif

typedef struct {
    void*   user;
    // Crée la texture Flutter et rend son identifiant (< 0 = échec).
    int64_t (*create)(void* user);
    // Signale qu'une nouvelle image est disponible.
    void    (*mark)(void* user);
    // Détruit la texture Flutter.
    void    (*destroy)(void* user);
} RewampWinTextureOps;

// Appelé une fois, à l'enregistrement du greffon. Sans vtable les visualiseurs
// restent inactifs plutôt que de planter.
REWAMP_VIZ_WIN_API void rewamp_viz_windows_set_texture_ops(const RewampWinTextureOps* ops);

// ── Mode GPU (défaut): une texture Direct3D 11 PARTAGÉE, sans copie ──────────
// Rend le HANDLE DXGI partagé du tampon publié (ou NULL si rien ne l'est
// encore) et sa taille. Appelé depuis le fil de rastérisation de Flutter.
REWAMP_VIZ_WIN_API void* rewamp_gl_windows_front_handle(int* w, int* h);

// ── Mode PIXELS: le repli, relecture sur le processeur ───────────────────────
// Posé par le greffon AVANT tout enregistrement (REWAMP_VIZ_PIXEL_MODE=1).
REWAMP_VIZ_WIN_API void rewamp_gl_windows_set_pixel_mode(int enabled);
REWAMP_VIZ_WIN_API int  rewamp_gl_windows_pixel_mode(void);
// Copie l'image publiée dans le tampon de l'appelant (réalloué au besoin), en
// RGBA, première ligne = haut de l'image. Rend 0 si rien n'a encore été publié.
REWAMP_VIZ_WIN_API int  rewamp_gl_windows_copy_front_pixels(uint8_t** buf, size_t* cap,
                                                            int* w, int* h);

#ifdef __cplusplus
}
#endif
#endif /* REWAMP_VIZ_WINDOWS_H */
