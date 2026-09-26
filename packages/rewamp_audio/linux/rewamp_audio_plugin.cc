// Pont visualiseurs ↔ Flutter pour Linux de bureau.
// Parallèle de src/apple/rewamp_viz_plugin.mm et de src/android/rewamp_viz_android.cpp.
//
// Ce fichier ne contient QUE ce qui exige les en-têtes de l'embedder: la
// sous-classe FlTextureGL et l'installation du vtable. Toute la logique
// (modes, register, notify, cycle de vie) vit dans le MOTEUR — voir
// src/linux/rewamp_viz_linux.h pour la raison: Dart ouvre librewamp_audio.so
// et c'est là qu'il cherche les symboles, alors que seul un vrai plugin de
// plateforme reçoit un FlTextureRegistrar.
//
// Le moteur rend hors écran dans SON contexte EGL et publie chaque frame en
// EGLImageKHR; populate() l'importe dans le contexte de Flutter avec
// glEGLImageTargetTexture2DOES. Zéro copie.

#include "include/rewamp_audio/rewamp_audio_plugin.h"

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include "../src/rewamp_gl.h"          // rewamp_gl_generation
#include "../src/linux/rewamp_gl_linux.h"
#include "../src/linux/rewamp_viz_linux.h"

#include <stdio.h>
#include <stdlib.h>

// ── Texture Flutter ─────────────────────────────────────────────────────────
G_DECLARE_FINAL_TYPE(RewampVizTexture, rewamp_viz_texture, REWAMP, VIZ_TEXTURE,
                     FlTextureGL)

struct _RewampVizTexture {
  FlTextureGL parent_instance;
  // Une texture PAR tampon du triple buffer, dans le contexte de Flutter.
  // On les garde d'une frame sur l'autre: un EGLImage est une VUE vivante de la
  // texture du moteur, donc une fois liée il n'y a plus rien à refaire tant que
  // l'image ne change pas. Une reconstruction du monde GL (resize, contexte
  // perdu) en crée de nouvelles — d'où la comparaison sur `bound_image` plutôt
  // qu'un simple drapeau « déjà lié ».
  GLuint   tex[3];
  void*    bound_image[3];
  // ⚠️ Comparer l'ADRESSE de l'EGLImage ne suffit pas: recréer les tampons
  // détruit les anciennes images et l'allocateur peut resservir la MÊME adresse
  // pour une neuve. On se lierait alors à une image morte, sans erreur GL — et
  // le symptôme est un clignotement rapide, puisque seuls CERTAINS des trois
  // tampons héritent d'une adresse resservie.
  //
  // Deux compteurs, et il faut les DEUX: la génération GL couvre la
  // reconstruction du contexte, l'ÉPOQUE couvre la recréation des seules images
  // (un resize / passage en plein écran, où le contexte survit et la génération
  // ne bouge donc pas). C'est ce second cas qui manquait.
  unsigned bound_gen[3];
  unsigned bound_epoch[3];
};

G_DEFINE_TYPE(RewampVizTexture, rewamp_viz_texture, fl_texture_gl_get_type())

static gboolean rewamp_viz_texture_populate(FlTextureGL* texture,
                                            uint32_t* target, uint32_t* name,
                                            uint32_t* width, uint32_t* height,
                                            GError** error) {
  RewampVizTexture* self = REWAMP_VIZ_TEXTURE(texture);
  rewamp_viz_stats_populate();   // REWAMP_VIZ_STATS=1, voir rewamp_viz_stats.cc

  // Le contexte de Flutter est courant ICI et nulle part ailleurs: c'est le
  // seul endroit d'où l'on peut connaître SON EGLDisplay, qu'aucune API
  // publique de l'embedder n'expose. Un EGLImage n'étant valide que sur son
  // display, on confronte l'hypothèse du moteur à la réalité. Sans écart, ce
  // test ne coûte rien et ne se fait qu'une fois.
  rewamp_gl_linux_check_display((void*)eglGetCurrentDisplay());

  int w = 0, h = 0, index = 0;
  unsigned epoch = 0;
  void* image = rewamp_gl_linux_front_image(&w, &h, &epoch, &index);
  if (!image || w <= 0 || h <= 0 || index < 0 || index > 2) {
    static bool warned = false;
    if (!warned) {
      warned = true;
      fprintf(stderr, "[rewamp_viz] populate appelé mais rien de publié "
                      "(image=%p %dx%d tampon=%d)\n", image, w, h, index);
    }
    g_set_error(error, g_quark_from_static_string("rewamp"), 0,
                "aucune frame publiée");
    return FALSE;
  }

  static PFNGLEGLIMAGETARGETTEXTURE2DOESPROC p_bind = nullptr;
  if (!p_bind) {
    p_bind = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress(
        "glEGLImageTargetTexture2DOES");
    if (!p_bind) {
      g_set_error(error, g_quark_from_static_string("rewamp"), 0,
                  "GL_OES_EGL_image absent");
      return FALSE;
    }
  }

  if (self->tex[index] == 0) {
    glGenTextures(1, &self->tex[index]);
    self->bound_image[index] = nullptr;
    self->bound_gen[index]   = 0u - 1u;
    self->bound_epoch[index] = 0u;
  }
  const unsigned gen = rewamp_gl_generation();
  bool rebound = false;
  glBindTexture(GL_TEXTURE_2D, self->tex[index]);
  if (self->bound_image[index] != image ||
      self->bound_gen[index]   != gen   ||
      self->bound_epoch[index] != epoch) {
    p_bind(GL_TEXTURE_2D, (GLeglImageOES)image);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    self->bound_image[index] = image;
    self->bound_gen[index]   = gen;
    self->bound_epoch[index] = epoch;
    rebound = true;
  }

  // Trace UNE SEULE FOIS. Linux est une plateforme neuve pour cette chaîne et
  // « Flutter consomme-t-il la texture ? » n'a pas d'autre signal observable:
  // si populate n'est jamais appelé, le visualiseur reste noir sans un mot.
  // Une seule ligne, jamais par frame — un printf sur le fil de frame coûte des
  // millisecondes et fabriquerait l'à-coup qu'il prétend mesurer.
  static bool announced = false;
  if (!announced) {
    announced = true;
    fprintf(stderr, "[rewamp_viz] texture GL consommée par Flutter (%dx%d)\n", w, h);
  }

  // REWAMP_VIZ_DEBUG=1: relire les pixels DEPUIS LE CONTEXTE DE FLUTTER. C'est
  // le seul endroit qui prouve que l'image importée porte vraiment le rendu du
  // moteur — importer une EGLImage d'un AUTRE display ne lève aucune erreur GL,
  // ça rend simplement du noir, et c'est exactement ce qu'on cherche à
  // distinguer. Drapeau d'EXÉCUTION, pas #ifdef DEBUG: on veut pouvoir le
  // demander sur une build normale.
  //
  // Déclenché sur les (RE)LIAISONS d'image et non sur la première frame: une
  // correction de display recrée les EGLImage, et seul l'état d'APRÈS dit si la
  // chaîne est saine. Borné à quelques tirs — diagnostic, pas mesure par frame.
  static int probes = 0;
  if (rebound && probes < 6 && getenv("REWAMP_VIZ_DEBUG")) {
    probes++;
    {
      GLuint fbo = 0;
      glGenFramebuffers(1, &fbo);
      glBindFramebuffer(GL_FRAMEBUFFER, fbo);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                             self->tex[index], 0);
      if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) {
        const int n = w * h;
        unsigned char* px = (unsigned char*)malloc((size_t)n * 4);
        if (px) {
          glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, px);
          long lit = 0;
          for (int i = 0; i < n; i++)
            if (px[i*4] > 8 || px[i*4+1] > 8 || px[i*4+2] > 8) lit++;
          fprintf(stderr, "[rewamp_viz] relecture depuis le contexte Flutter: "
                          "%ld/%d pixels allumés (%.1f%%)  [tampon=%d image=%p époque=%u]\n",
                  lit, n, 100.0 * lit / n, index, image, epoch);
          free(px);
        }
      } else {
        fprintf(stderr, "[rewamp_viz] relecture impossible: FBO incomplet\n");
      }
      glBindFramebuffer(GL_FRAMEBUFFER, 0);
      glDeleteFramebuffers(1, &fbo);
    }
  }

  *target = GL_TEXTURE_2D;
  *name   = self->tex[index];
  *width  = (uint32_t)w;
  *height = (uint32_t)h;
  return TRUE;
}

static void rewamp_viz_texture_class_init(RewampVizTextureClass* klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = rewamp_viz_texture_populate;
}

static void rewamp_viz_texture_init(RewampVizTexture* self) {
  for (int i = 0; i < 3; i++) {
    self->tex[i] = 0; self->bound_image[i] = nullptr;
    self->bound_gen[i] = 0u - 1u; self->bound_epoch[i] = 0u;
  }
}

// ── Texture par TAMPON DE PIXELS: le repli X11 / GLX ────────────────────────
// Sous X11, Flutter est en GLX et l'EGLImage ci-dessus ne s'importe pas (voir
// rewamp_gl_linux.h, « mode pixels »). Ici le moteur a RELU l'image sur le
// processeur; Flutter la remonte en texture dans SON contexte, quel qu'il
// soit. Le tampon appartient à cette texture, donc il survit exactement le
// temps que la doc de FlPixelBufferTexture exige (« jusqu'au prochain tour du
// fil de rendu ») et un resize ne peut pas le lui retirer sous les pieds.
G_DECLARE_FINAL_TYPE(RewampVizPixelTexture, rewamp_viz_pixel_texture, REWAMP,
                     VIZ_PIXEL_TEXTURE, FlPixelBufferTexture)

struct _RewampVizPixelTexture {
  FlPixelBufferTexture parent_instance;
  uint8_t* buf;
  size_t   cap;
};

G_DEFINE_TYPE(RewampVizPixelTexture, rewamp_viz_pixel_texture,
              fl_pixel_buffer_texture_get_type())

static gboolean rewamp_viz_pixel_texture_copy_pixels(FlPixelBufferTexture* texture,
                                                     const uint8_t** out_buffer,
                                                     uint32_t* width, uint32_t* height,
                                                     GError** error) {
  RewampVizPixelTexture* self = REWAMP_VIZ_PIXEL_TEXTURE(texture);
  rewamp_viz_stats_populate();
  int w = 0, h = 0;
  if (!rewamp_gl_linux_copy_front_pixels(&self->buf, &self->cap, &w, &h)) {
    g_set_error(error, g_quark_from_static_string("rewamp"), 0,
                "aucune image relue pour l'instant");
    return FALSE;
  }
  static bool announced = false;
  if (!announced) {
    announced = true;
    fprintf(stderr, "[rewamp_viz] mode PIXELS (X11/GLX): image relue consommée "
                    "par Flutter (%dx%d)\n", w, h);
  }
  *out_buffer = self->buf;
  *width  = (uint32_t)w;
  *height = (uint32_t)h;
  return TRUE;
}

static void rewamp_viz_pixel_texture_finalize(GObject* obj) {
  RewampVizPixelTexture* self = REWAMP_VIZ_PIXEL_TEXTURE(obj);
  free(self->buf); self->buf = nullptr; self->cap = 0;
  G_OBJECT_CLASS(rewamp_viz_pixel_texture_parent_class)->finalize(obj);
}

static void rewamp_viz_pixel_texture_class_init(RewampVizPixelTextureClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = rewamp_viz_pixel_texture_copy_pixels;
  G_OBJECT_CLASS(klass)->finalize = rewamp_viz_pixel_texture_finalize;
}

static void rewamp_viz_pixel_texture_init(RewampVizPixelTexture* self) {
  self->buf = nullptr; self->cap = 0;
}

// ── Vtable remis au moteur ──────────────────────────────────────────────────
static FlTextureRegistrar* g_registrar = nullptr;
static FlTexture*          g_texture   = nullptr;   // GL (EGLImage) ou pixels

static int64_t ops_create(void*) {
  if (!g_registrar) return -1;
  g_texture = rewamp_gl_linux_pixel_mode()
      ? FL_TEXTURE(g_object_new(rewamp_viz_pixel_texture_get_type(), nullptr))
      : FL_TEXTURE(g_object_new(rewamp_viz_texture_get_type(), nullptr));
  if (!fl_texture_registrar_register_texture(g_registrar, g_texture)) {
    g_clear_object(&g_texture);
    return -2;
  }
  return (int64_t)fl_texture_get_id(g_texture);
}

static void ops_mark(void*) {
  if (g_registrar && g_texture)
    fl_texture_registrar_mark_texture_frame_available(g_registrar, g_texture);
}

static void ops_destroy(void*) {
  if (g_registrar && g_texture)
    fl_texture_registrar_unregister_texture(g_registrar, g_texture);
  g_clear_object(&g_texture);
}

// ── EGLDisplay: le trouver AVANT, pas le corriger APRÈS ─────────────────────
//
// L'embedder n'expose pas son EGLDisplay, et on ne peut l'observer que depuis
// populate() — c'est-à-dire trop tard, une fois nos contextes et nos EGLImage
// déjà créés sur un AUTRE display. Le moteur sait se corriger (il reconstruit
// tout et incrémente sa génération), mais cette reconstruction en vol laissait
// une session visiblement instable: l'image CLIGNOTAIT jusqu'à ce qu'on ferme
// et rouvre le lecteur, ce qui repartait proprement sur le bon display. Le
// symptôme désignait le remède: ne jamais se tromper au départ.
//
// GDK connaît l'affichage natif, et EGL garantit que deux demandes portant sur
// le MÊME affichage natif rendent le MÊME EGLDisplay. On le dérive donc ici,
// avant que quoi que ce soit ne soit créé. Si la dérivation échoue (backend
// inattendu), on ne perd rien: le moteur retombe sur EGL_DEFAULT_DISPLAY et sa
// correction en vol reste le filet.
static void* derive_flutter_egl_display() {
  GdkDisplay* gdpy = gdk_display_get_default();
  if (!gdpy) return nullptr;

  PFNEGLGETPLATFORMDISPLAYEXTPROC getPlatformDisplay =
      (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");

#ifdef GDK_WINDOWING_WAYLAND
  if (GDK_IS_WAYLAND_DISPLAY(gdpy)) {
    void* wl = gdk_wayland_display_get_wl_display(GDK_WAYLAND_DISPLAY(gdpy));
    if (!wl) return nullptr;
    if (getPlatformDisplay)
      return (void*)getPlatformDisplay(EGL_PLATFORM_WAYLAND_EXT, wl, nullptr);
    return (void*)eglGetDisplay((EGLNativeDisplayType)wl);
  }
#endif
#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_DISPLAY(gdpy)) {
    void* xd = gdk_x11_display_get_xdisplay(GDK_X11_DISPLAY(gdpy));
    if (!xd) return nullptr;
    if (getPlatformDisplay)
      return (void*)getPlatformDisplay(EGL_PLATFORM_X11_EXT, xd, nullptr);
    return (void*)eglGetDisplay((EGLNativeDisplayType)xd);
  }
#endif
  return nullptr;
}

// ── Enregistrement ──────────────────────────────────────────────────────────
void rewamp_audio_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  g_registrar = fl_plugin_registrar_get_texture_registrar(registrar);
  if (!g_registrar) {
    fprintf(stderr, "[rewamp_viz] pas de FlTextureRegistrar — visualiseurs inactifs\n");
    return;
  }
  void* dpy = derive_flutter_egl_display();
  if (dpy) rewamp_gl_linux_set_display(dpy);

  // Le backend GDK décide de l'API du contexte que Flutter recevra: EGL sous
  // Wayland, GLX sous X11 (mesuré, docs/FLATPAK.md §5). C'est connu ICI, avant
  // le premier enregistrement — pas besoin d'attendre populate() pour le voir.
  // REWAMP_VIZ_PIXEL_MODE=0|1 force le choix — porte de secours pour un
  // utilisateur, et le seul moyen de comparer les deux chemins sur la MÊME
  // session (c'est ainsi qu'on a mesuré que le gel au démarrage sous XWayland
  // n'appartenait pas à ce mode).
  int pixel = 0;
#ifdef GDK_WINDOWING_X11
  {
    GdkDisplay* gdpy = gdk_display_get_default();
    if (gdpy && GDK_IS_X11_DISPLAY(gdpy)) {
      pixel = 1;
      rewamp_viz_linux_set_display_is_x11(1);   // « toujours au premier plan » s'y débloque
    }
  }
#endif
  if (const char* force = getenv("REWAMP_VIZ_PIXEL_MODE")) pixel = (force[0] == '1');
  if (pixel) {
    rewamp_gl_linux_set_pixel_mode(1);
    fprintf(stderr, "[rewamp_viz] Flutter en GLX (X11) — visualiseurs en mode "
                    "PIXELS (relecture CPU)\n");
  }

  static const RewampLinuxTextureOps ops = {
      nullptr, ops_create, ops_mark, ops_destroy};
  rewamp_viz_linux_set_texture_ops(&ops);
}
