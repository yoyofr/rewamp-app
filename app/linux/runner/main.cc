#include "my_application.h"

#include <cstdio>
#include <cstdlib>
#include <stdexcept>

// Oracle du déroulement d'exceptions C++ (voir runner/CMakeLists.txt, libgcc_s
// lié EN TÊTE): `REWAMP_SELFTEST_EH=1 rewamp` lance et rattrape une exception
// puis sort. Un unwinder incompatible fait « terminate called after throwing »
// au lieu d'imprimer « eh ok » — c'est ce que la CI de l'AppImage vérifie.
static int selftest_exceptions() {
  try {
    throw std::runtime_error("selftest");
  } catch (const std::exception& e) {
    std::printf("eh ok (%s)\n", e.what());
    return 0;
  }
  return 1;
}

int main(int argc, char** argv) {
  if (std::getenv("REWAMP_SELFTEST_EH") != nullptr) return selftest_exceptions();

  // ⚠️ On NE force PAS le back-end X11 — tenté le 2026-09-20, annulé le 21.
  //
  // `window_manager` implémente « toujours au premier plan » et le placement
  // de fenêtre (setBounds) par de l'EWMH, donc du X11: sous Wayland ces appels
  // n'émettent AUCUN message de protocole (mesuré) et ne font rien. Forcer
  // `GDK_BACKEND=x11,wayland` les rendait fonctionnels…
  //
  // …et rendait NOIRS tous les visualiseurs GL. Mesuré, sur le contexte que
  // GTK3 donne à Flutter (`gdk_window_create_gl_context`):
  //
  //   Wayland → contexte EGL   (eglGetCurrentDisplay = un vrai affichage)
  //   X11     → contexte GLX   (eglGetCurrentDisplay = EGL_NO_DISPLAY)
  //
  // Or les visualiseurs transmettent leurs images par EGLImage
  // (rewamp_audio_plugin.cc, `glEGLImageTargetTexture2DOES`), qui ne se lie
  // QUE dans un contexte EGL. Sous GLX il n'existe même pas de chemin qui
  // marche. Échanger les visualiseurs contre l'épinglage, c'était échanger la
  // fonction centrale contre un confort.
  //
  // Le back-end reste donc celui que GTK choisit. « Toujours au premier plan »
  // sous Wayland ne peut pas être DEMANDÉ par l'app; le compositeur le propose
  // dans son menu de fenêtre (Alt+Espace sous GNOME), que l'app peut OUVRIR
  // par `xdg_toplevel.show_window_menu`. Voir docs/FLATPAK.md §5.
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
