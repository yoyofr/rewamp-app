#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

#include <glib/gstdio.h>

#include <cstdio>
#include <string>
#include <vector>

#include "../../native_cli/rewamp_cli.h"

#ifndef FLUTTER_VERSION
#define FLUTTER_VERSION ""
#endif

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // Instance UNIQUE (voir my_application_command_line): les lignes de
  // commande d'une seconde invocation, en attente que Dart les tire par le
  // canal `rewamp/cli` (`takePending`). Même discipline que l'ouverture de
  // fichiers sur Apple: le natif ne pousse jamais, il prévient.
  GPtrArray* pending_cli;   // de GStrv
  FlMethodChannel* cli_channel;
  // Démarrage à froid avec `--mini`: pas d'affichage à la première image —
  // Dart rétrécit la fenêtre puis la révèle (`rewamp/cli` `revealWindow`),
  // sinon on la voyait en grand une fraction de seconde. Filet: 5 s.
  gboolean launch_hidden;
  guint reveal_timeout;
  GtkWindow* window;
  // Référence gardée sur le moteur pour l'ARRÊTER nous-mêmes à la fin de la
  // boucle, avant la sortie du processus (voir window_delete_cb et shutdown).
  FlEngine* engine;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void reveal_launch_window(MyApplication* self) {
  if (self->reveal_timeout != 0) {
    g_source_remove(self->reveal_timeout);
    self->reveal_timeout = 0;
  }
  if (!self->launch_hidden || self->window == nullptr) return;
  self->launch_hidden = FALSE;
  gtk_widget_show(GTK_WIDGET(self->window));
}

static gboolean reveal_timeout_cb(gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->reveal_timeout = 0;
  reveal_launch_window(self);
  return G_SOURCE_REMOVE;
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  if (self->launch_hidden) {
    self->reveal_timeout = g_timeout_add_seconds(5, reveal_timeout_cb, self);
    return;
  }
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Fermeture de la fenêtre: quitter la boucle SANS détruire la fenêtre.
//
// ⚠️ Pourquoi ce gestionnaire existe. `window_manager` (à l'enregistrement de
// son greffon) DÉCONNECTE le `delete-event` de FlView — celui qui demandait à
// Dart la permission de sortir puis quittait proprement — et pose le sien, qui
// rend « empêcher la fermeture » (faux chez nous). GTK DÉTRUISAIT alors la
// fenêtre, donc la vue et son compositeur, pendant que le moteur tournait
// encore: le fil de rendu présentait une image dans un compositeur libéré.
// Symptômes: SIGSEGV à la sortie sur le Steam Deck (rappel de `FlTaskRunner`
// sur de la mémoire libérée), SIGABRT « g_mutex_clear() called on
// uninitialised or locked mutex » sur la VM de dev — 2 fermetures sur 3.
//
// On fait donc ce que fait Flutter lui-même (`quit_application` de
// fl_platform_handler.cc): détacher les fenêtres de l'application, puis
// quitter la boucle. Connecté APRÈS les greffons: si un jour Dart empêche la
// fermeture (`setPreventClose(true)`), le gestionnaire de `window_manager`
// rend TRUE et l'émission s'arrête avant d'arriver ici.
static gboolean window_delete_cb(GtkWidget* window, GdkEvent* event,
                                 gpointer user_data) {
  GApplication* app = G_APPLICATION(user_data);
  g_autoptr(GList) windows =
      g_list_copy(gtk_application_get_windows(GTK_APPLICATION(app)));
  for (GList* l = windows; l != nullptr; l = l->next) {
    gtk_window_set_application(GTK_WINDOW(l->data), nullptr);
  }
  g_application_quit(app);
  return TRUE;
}

static void set_launch_mini_setting(gboolean on);

// `takePending`: rend et VIDE le tampon, d'un coup — une ligne arrivée en
// vol est soit dans ce lot soit dans le prochain, jamais dans les deux.
static void cli_method_call_cb(FlMethodChannel* channel,
                               FlMethodCall* method_call, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(method_call), "takePending") == 0) {
    g_autoptr(FlValue) out = fl_value_new_list();
    for (guint i = 0; i < self->pending_cli->len; i++) {
      GStrv argv = static_cast<GStrv>(g_ptr_array_index(self->pending_cli, i));
      FlValue* one = fl_value_new_list();
      for (GStrv a = argv; a && *a; a++) {
        fl_value_append_take(one, fl_value_new_string(*a));
      }
      fl_value_append_take(out, one);
    }
    g_ptr_array_set_size(self->pending_cli, 0);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(out));
  } else if (g_strcmp0(fl_method_call_get_name(method_call), "revealWindow") == 0) {
    reveal_launch_window(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(fl_method_call_get_name(method_call), "setLaunchMini") == 0) {
    FlValue* v = fl_method_call_get_args(method_call);
    set_launch_mini_setting(v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL &&
                            fl_value_get_bool(v));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

// Les arguments BRUTS, précédés de `--cwd=<dossier courant de L'INVOCATION>`
// (pas du nôtre: une seconde instance peut être lancée d'ailleurs). Dart
// interprète tout (lib/cli_options.dart) — rendre les positionnels absolus ici
// transformait aussi la VALEUR d'une option (`--subsong 3` → `/home/u/3`).
static GStrv cli_args_with_cwd(GApplicationCommandLine* cmdline) {
  int argc = 0;
  g_auto(GStrv) argv = g_application_command_line_get_arguments(cmdline, &argc);
  // GPtrArray et pas GStrvBuilder: celui-ci exige glib 2.68, et le plancher
  // de l'AppImage est plus bas (docs/APPIMAGE.md).
  GPtrArray* out = g_ptr_array_new();
  const gchar* cwd = g_application_command_line_get_cwd(cmdline);
  if (cwd != nullptr) g_ptr_array_add(out, g_strconcat("--cwd=", cwd, nullptr));
  for (int i = 1; i < argc; i++) {   // argv[0] = l'exécutable
    g_ptr_array_add(out, g_strdup(argv[i]));
  }
  g_ptr_array_add(out, nullptr);
  return reinterpret_cast<GStrv>(g_ptr_array_free(out, FALSE));
}

// Le manifeste de la ligne de commande (native_cli/rewamp_cli.h), lu UNE fois:
// `<dossier de l'exécutable>/data/flutter_assets/assets/cli/cli_manifest.json`.
static const rewamp_cli::Manifest& cli_manifest() {
  static rewamp_cli::Manifest m;
  static bool done = false;
  if (!done) {
    done = true;
    g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
    if (exe != nullptr) {
      g_autofree gchar* dir = g_path_get_dirname(exe);
      g_autofree gchar* path =
          g_build_filename(dir, "data", "flutter_assets", "assets", "cli",
                           "cli_manifest.json", nullptr);
      m = rewamp_cli::LoadManifest(path);
    }
  }
  return m;
}

// Réglage « Au démarrage: mini lecteur », CONFIÉ par Dart (`setLaunchMini`,
// lib/launch_window.dart) parce qu'il doit être connu avant Dart: un fichier
// `launch_mini` dans le dossier de données de l'app — sa PRÉSENCE vaut oui.
static gchar* launch_mini_path() {
  return g_build_filename(g_get_user_data_dir(), APPLICATION_ID, "launch_mini",
                          nullptr);
}

static gboolean launch_mini_setting() {
  g_autofree gchar* path = launch_mini_path();
  return g_file_test(path, G_FILE_TEST_EXISTS);
}

static void set_launch_mini_setting(gboolean on) {
  g_autofree gchar* path = launch_mini_path();
  if (on) {
    g_autofree gchar* dir = g_path_get_dirname(path);
    (void)g_mkdir_with_parents(dir, 0700);
    (void)g_file_set_contents(path, "1\n", -1, nullptr);
  } else {
    (void)g_unlink(path);
  }
}

// Même règle que `planLaunch` (lib/local_open.dart): `--mini`, ou le réglage
// sans `--window`.
static gboolean launch_hidden_for(const rewamp_cli::Scan& scan) {
  return scan.Has("mini") || (!scan.Has("window") && launch_mini_setting());
}

// argv sans argv[0].
static std::vector<std::string> cli_tail(gchar** argv) {
  std::vector<std::string> out;
  if (argv == nullptr || argv[0] == nullptr) return out;
  for (gchar** a = argv + 1; *a != nullptr; a++) out.emplace_back(*a);
  return out;
}

// Implements GApplication::command_line — l'instance PRINCIPALE reçoit ici sa
// propre ligne de commande ET celles des invocations suivantes, transmises
// par D-Bus (G_APPLICATION_HANDLES_COMMAND_LINE, instance unique).
static int my_application_command_line(GApplication* application,
                                       GApplicationCommandLine* cmdline) {
  MyApplication* self = MY_APPLICATION(application);
  GStrv args = cli_args_with_cwd(cmdline);
  if (self->window == nullptr) {
    // Premier lancement: les arguments vont à `main()` de Dart, comme avant.
    int argc = 0;
    g_auto(GStrv) raw = g_application_command_line_get_arguments(cmdline, &argc);
    self->launch_hidden =
        launch_hidden_for(rewamp_cli::ScanArgs(cli_tail(raw), cli_manifest()));
    g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
    self->dart_entrypoint_arguments = args;
    g_application_activate(application);
    return 0;
  }
  // Seconde invocation: au tampon, Dart est prévenu et tire.
  int argc = 0;
  g_auto(GStrv) raw = g_application_command_line_get_arguments(cmdline, &argc);
  const bool remote_only =
      rewamp_cli::ScanArgs(cli_tail(raw), cli_manifest()).RemoteOnly(cli_manifest());
  g_ptr_array_add(self->pending_cli, args);
  if (self->cli_channel != nullptr) {
    fl_method_channel_invoke_method(self->cli_channel, "argsAvailable", nullptr,
                                    nullptr, nullptr, nullptr);
  }
  // Piloter la lecture ne vole pas le premier plan; ouvrir des fichiers, si.
  if (!remote_only) gtk_window_present(self->window);
  return 0;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  // Une seconde « activation » (sans argument, depuis le lanceur) ne doit
  // pas ouvrir une seconde fenêtre: elle ramène la première.
  if (self->window != nullptr) {
    gtk_window_present(self->window);
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "rewamp");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "rewamp");
  }

  gtk_window_set_default_size(window, 1280, 720);

  // Taille minimale (480x640, en parité avec macOS): posée depuis DART
  // (lib/mini_window.dart, `MiniWindow.init` -> window_manager, qui passe par
  // des geometry hints). ⚠️ NE PAS la remettre ici en
  // `gtk_widget_set_size_request`: c'est un plancher DUR que les geometry
  // hints ne peuvent pas traverser, donc le mini lecteur (440x132) ne pourrait
  // jamais descendre sous 480x640.

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Fond de l'intro (#160A1E), en parité avec macOS (MainFlutterWindow.swift)
  // et avec kSplashBg de splash_intro.dart, qui est la SOURCE de cette valeur.
  //
  // ⚠️ La raison n'est PAS tout à fait celle de macOS. Là-bas, la couleur évite
  // un flash avant la première frame Flutter; ici ce flash n'existe pas, car
  // first_frame_cb ne montre la fenêtre qu'une fois Flutter prêt. Ce qu'elle
  // couvre sur Linux, c'est ce qui se voit quand Flutter n'a rien dessiné
  // ENCORE à cet endroit — typiquement les zones exposées pendant un
  // redimensionnement, qui sortaient en noir franc au lieu du fond de l'intro.
  gdk_rgba_parse(&background_color, "#160A1E");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // APRÈS fl_register_plugins: window_manager vient de retirer le gestionnaire
  // de fermeture de FlView (voir window_delete_cb).
  self->engine = FL_ENGINE(g_object_ref(fl_view_get_engine(view)));
  g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_cb),
                   application);

  // Canal des lignes de commande transmises par une seconde instance.
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->cli_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(self->engine), "rewamp/cli",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->cli_channel,
                                            cli_method_call_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
//
// Instance UNIQUE: on s'enregistre sur le bus de session, puis on rend la main
// (FALSE) — `g_application_run` envoie alors la ligne de commande à
// l'instance PRINCIPALE si elle existe déjà (et ce processus se termine),
// sinon l'appelle ici même (my_application_command_line).
//
// ⚠️ Sans bus de session (rare, mais un lancement nu sous un autre
// utilisateur, un conteneur minimal…), l'enregistrement échoue: on retombe
// sur l'ancien comportement, une instance locale, plutôt que de refuser de
// démarrer — c'est ce que l'implémentation par défaut aurait fait.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Ce que le natif décide AVANT Dart (rewamp_cli.h): `--help` et `--version`
  // s'impriment ici, sans bus ni fenêtre.
  const rewamp_cli::Manifest& manifest = cli_manifest();
  const rewamp_cli::Scan scan = rewamp_cli::ScanArgs(cli_tail(*arguments), manifest);
  if (scan.Has("help") || scan.Has("version")) {
    const std::string out = scan.Has("help")
                                ? rewamp_cli::HelpText(manifest, FLUTTER_VERSION)
                                : rewamp_cli::VersionLine(FLUTTER_VERSION);
    fputs(out.c_str(), stdout);
    fflush(stdout);
    *exit_status = 0;
    return TRUE;
  }
  g_autoptr(GError) error = nullptr;
  const bool registered = g_application_register(application, nullptr, &error);
  // Une commande de pilotage seule sans instance lancée: le dire, plutôt que
  // de démarrer l'app pour rien. Sans bus, aucune instance n'est joignable.
  if (scan.RemoteOnly(manifest) &&
      (!registered || !g_application_get_is_remote(application))) {
    fputs(rewamp_cli::kNotRunning, stderr);
    *exit_status = 1;
    return TRUE;
  }
  if (!registered) {
    g_warning("Instance unique indisponible (%s): instance locale.",
              error->message);
    self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
    self->launch_hidden = launch_hidden_for(scan);
    g_application_activate(application);
    *exit_status = 0;
    return TRUE;
  }
  return FALSE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Arrêter le moteur MAINTENANT, boucle finie mais GTK et GL encore vivants.
  // Sans ça ses fils de rendu et d'E/S tournent encore pendant `exit()` et
  // meurent dans le pilote GL qu'on démonte sous eux (mesuré: 2 sorties sur 10
  // plantaient encore dans Mesa avec window_delete_cb seul). La destruction du
  // moteur appelle FlutterEngineShutdown, qui JOINT ces fils. Garder la
  // référence sans cet arrêt ne suffit pas: c'est ce qui prolongeait la course.
  if (self->engine != nullptr) {
    g_object_run_dispose(G_OBJECT(self->engine));
    g_clear_object(&self->engine);
  }

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_pointer(&self->pending_cli, g_ptr_array_unref);
  g_clear_object(&self->cli_channel);
  if (self->reveal_timeout != 0) {
    g_source_remove(self->reveal_timeout);
    self->reveal_timeout = 0;
  }
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->pending_cli =
      g_ptr_array_new_with_free_func(reinterpret_cast<GDestroyNotify>(g_strfreev));
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_COMMAND_LINE,
                                     nullptr));
}
