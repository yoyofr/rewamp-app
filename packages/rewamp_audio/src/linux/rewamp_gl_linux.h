// Pont interne entre rewamp_gl_linux.cc (moteur) et le plugin GTK
// (linux/rewamp_audio_plugin.cc). Ce n'est PAS de l'API FFI: rien ici n'est
// cherché depuis Dart, tout vit dans la même .so.
#ifndef REWAMP_GL_LINUX_H
#define REWAMP_GL_LINUX_H

#ifdef __cplusplus
extern "C" {
#endif

/* Le moteur est compile en -fvisibility=hidden et le plugin GTK est une .so
 * SEPAREE: sans visibilite explicite, ces trois-la existent dans le binaire
 * mais pas dans sa table dynamique, et le lien du plugin echoue. Ce n'est pas
 * de l'API FFI pour autant -- Dart n'y touche jamais. */
#define REWAMP_GL_LINUX_API __attribute__((visibility("default")))

// Le display que le plugin déduit de GdkDisplay, posé AVANT toute création de
// contexte. Un EGLImage n'étant valide que sur son display, il doit être celui
// que Flutter utilise — voir l'en-tête de rewamp_gl_linux.cc.
REWAMP_GL_LINUX_API void rewamp_gl_linux_set_display(void* egl_display);

// Appelé depuis populate(), avec le contexte Flutter courant.
// Rend l'EGLImageKHR du tampon publié (ou NULL), sa taille, l'ÉPOQUE des images
// et l'index du tampon (la texture importée est mise en cache PAR tampon côté
// plugin). ⚠️ L'époque, pas un numéro de frame: elle change quand les images
// sont recréées (resize/plein écran), et c'est le SEUL signal fiable pour
// relier — comparer l'adresse ne suffit pas, l'allocateur les resert.
REWAMP_GL_LINUX_API void* rewamp_gl_linux_front_image(int* w, int* h, unsigned* serial, int* index);

// Vrai si un ecart de display a ete detecte et que le monde GL n'a pas encore
// ete reconstruit. Le chemin de RENDU doit le consulter: rewamp_gl_ensure()
// n'est appele que depuis l'init d'un renderer, donc sans ca la correction est
// notee et jamais appliquee -- ce qui donne un visualiseur noir, en silence.
REWAMP_GL_LINUX_API int rewamp_gl_linux_display_rebuild_pending(void);

// Confronte l'hypothèse du plugin à la réalité observée dans populate().
// Ne fait rien après le premier appel.
REWAMP_GL_LINUX_API void rewamp_gl_linux_check_display(void* flutter_egl_display);

#ifdef __cplusplus
}
#endif
#endif /* REWAMP_GL_LINUX_H */
