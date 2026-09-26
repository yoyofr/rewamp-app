// Vtable que le plugin GTK installe dans le moteur.
//
// ⚠️ C'est le point d'architecture propre à Linux, et il n'a d'équivalent nulle
// part ailleurs. Sur Apple le moteur et le plugin sont liés dans le MÊME
// binaire (Dart résout par DynamicLibrary.process()); sur Android ils sont dans
// la MÊME .so. Ici, Flutter impose deux bibliothèques distinctes: le moteur,
// que Dart ouvre par son nom en FFI, et `<paquet>_plugin`, la seule à qui
// l'embedder remet un FlTextureRegistrar.
//
// Les points d'entrée cherchés par Dart (rewamp_viz_register, …) doivent donc
// vivre dans le MOTEUR — sinon lookupFunction ne les trouve pas et l'option
// échoue en silence — le mode d'échec classique des exports FFI. C'est le
// PLUGIN qui se branche dessus, pas
// l'inverse: il dépose ici de quoi créer, notifier et détruire une texture.
#ifndef REWAMP_VIZ_LINUX_H
#define REWAMP_VIZ_LINUX_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define REWAMP_VIZ_LINUX_API __attribute__((visibility("default")))

typedef struct {
    void*   user;
    // Crée la texture Flutter et rend son identifiant (< 0 = échec).
    int64_t (*create)(void* user);
    // Signale qu'une nouvelle frame est disponible.
    void    (*mark)(void* user);
    // Détruit la texture Flutter.
    void    (*destroy)(void* user);
} RewampLinuxTextureOps;

// Appelé une fois, à l'enregistrement du plugin. Un vtable NULL laisse les
// visualiseurs inactifs plutôt que de planter.
REWAMP_VIZ_LINUX_API void rewamp_viz_linux_set_texture_ops(const RewampLinuxTextureOps* ops);

// Le backend GDK est-il X11 ? Posé par le plugin à l'enregistrement; lu par
// Dart via rewamp_linux_display_is_x11 (rewamp_audio.h).
REWAMP_VIZ_LINUX_API void rewamp_viz_linux_set_display_is_x11(int yes);

// Statistiques de cadence (REWAMP_VIZ_STATS=1), voir rewamp_viz_stats.cc. Le
// greffon appelle `populate` depuis le fil de rastérisation; le moteur appelle
// les deux autres autour de chaque rendu. Sans la variable, ce sont des retours
// immédiats.
void rewamp_viz_stats_render_begin(void);
void rewamp_viz_stats_render_end(void);
void rewamp_viz_stats_lap(int slot, double ms);   // 0 lier, 1 readPixels, 2 map+copie, 3 rendre, 4 attente fence, 5 rendu viz CPU
REWAMP_VIZ_LINUX_API void rewamp_viz_stats_populate(void);

#ifdef __cplusplus
}
#endif
#endif /* REWAMP_VIZ_LINUX_H */
