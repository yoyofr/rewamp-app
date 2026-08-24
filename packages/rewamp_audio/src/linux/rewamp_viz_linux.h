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

#ifdef __cplusplus
}
#endif
#endif /* REWAMP_VIZ_LINUX_H */
