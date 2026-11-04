#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

#include "media_controls.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Instance UNIQUE: étiquette du WM_COPYDATA par lequel une seconde
  // invocation transmet sa ligne de commande (main.cpp). « RWMP ».
  static constexpr ULONG_PTR kCliCopyDataTag = 0x52574D50;
  // Même charge, sans ramener la fenêtre: commande de pilotage seule.
  static constexpr ULONG_PTR kCliQuietCopyDataTag = 0x52574D51;

  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Démarrage à froid avec `--mini` (main.cpp): pas de Show() à la première
  // image — Dart rétrécit la fenêtre puis la révèle (`rewamp/cli`
  // `revealWindow`), sinon on la voyait en grand une fraction de seconde.
  // Filet: révélée d'office au bout de 5 s. Avant Create().
  void set_launch_hidden(bool hidden) { launch_hidden_ = hidden; }

  // Réglage « Au démarrage: mini lecteur », CONFIÉ par Dart (`setLaunchMini`,
  // lib/launch_window.dart) parce qu'il doit être connu avant Dart: valeur
  // DWORD `LaunchMini` sous HKCU\Software\app.rewamp.Rewamp.
  static bool LaunchMiniSetting();
  static void SetLaunchMiniSetting(bool on);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Session média système (SMTC), alimentée par lib/media_session_windows.dart.
  std::unique_ptr<MediaControls> media_controls_;

  // Lignes de commande reçues d'une seconde instance, en attente que Dart les
  // tire (`takePending` sur `rewamp/cli`). Le natif ne pousse jamais: il
  // prévient (`argsAvailable`), Dart tire — pas de course au démarrage.
  std::vector<std::vector<std::string>> pending_cli_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> cli_channel_;

  bool launch_hidden_ = false;
  static constexpr UINT_PTR kRevealTimerId = 0x52574D52;
  void RevealLaunchWindow();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
