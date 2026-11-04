#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // La session média se demande pour la fenêtre de PREMIER niveau (celle que
  // la barre des tâches connaît), pas pour la vue enfant de Flutter.
  media_controls_ = std::make_unique<MediaControls>(
      GetHandle(), flutter_controller_->engine()->messenger());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Canal des lignes de commande transmises par une seconde instance.
  cli_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "rewamp/cli",
      &flutter::StandardMethodCodec::GetInstance());
  cli_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setLaunchMini") {
          const auto* on = std::get_if<bool>(call.arguments());
          SetLaunchMiniSetting(on != nullptr && *on);
          result->Success();
          return;
        }
        if (call.method_name() == "revealWindow") {
          RevealLaunchWindow();
          result->Success();
          return;
        }
        if (call.method_name() != "takePending") {
          result->NotImplemented();
          return;
        }
        // Rend et VIDE le tampon d'un coup: une ligne arrivée en vol est soit
        // dans ce lot soit dans le prochain, jamais dans les deux.
        flutter::EncodableList out;
        for (const auto& argv : pending_cli_) {
          flutter::EncodableList one;
          for (const auto& a : argv) one.emplace_back(a);
          out.emplace_back(std::move(one));
        }
        pending_cli_.clear();
        result->Success(flutter::EncodableValue(std::move(out)));
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (launch_hidden_) {
      ::SetTimer(GetHandle(), kRevealTimerId, 5000, nullptr);
    } else {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Avant le moteur: le canal de la session vit sur son messager.
  media_controls_ = nullptr;
  cli_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case MediaControls::kButtonMessage:
      if (media_controls_) media_controls_->DrainPendingEvents();
      return 0;
    case WM_TIMER:
      if (wparam == kRevealTimerId) {
        RevealLaunchWindow();
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_COPYDATA: {
      // Seconde instance (main.cpp): arguments UTF-8 séparés par des NUL.
      const auto* cds = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (cds == nullptr || (cds->dwData != kCliCopyDataTag &&
                             cds->dwData != kCliQuietCopyDataTag)) {
        break;
      }
      std::vector<std::string> argv;
      const char* p = static_cast<const char*>(cds->lpData);
      const char* end = p + cds->cbData;
      while (p < end) {
        const char* z = static_cast<const char*>(memchr(p, 0, end - p));
        if (z == nullptr) z = end;
        if (z > p) argv.emplace_back(p, z - p);
        p = z + 1;
      }
      pending_cli_.push_back(std::move(argv));
      if (cli_channel_) cli_channel_->InvokeMethod("argsAvailable", nullptr);
      // Ramener la fenêtre: l'instance qui envoie nous a autorisés à prendre
      // le premier plan (AllowSetForegroundWindow), sinon Windows refuserait.
      if (cds->dwData == kCliCopyDataTag) {
        if (::IsIconic(hwnd)) ::ShowWindow(hwnd, SW_RESTORE);
        ::SetForegroundWindow(hwnd);
      }
      return TRUE;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RevealLaunchWindow() {
  ::KillTimer(GetHandle(), kRevealTimerId);
  if (!launch_hidden_) return;
  launch_hidden_ = false;
  Show();
}

static constexpr wchar_t kRewampRegKey[] = L"Software\\app.rewamp.Rewamp";

bool FlutterWindow::LaunchMiniSetting() {
  DWORD value = 0;
  DWORD size = sizeof(value);
  if (::RegGetValueW(HKEY_CURRENT_USER, kRewampRegKey, L"LaunchMini",
                     RRF_RT_REG_DWORD, nullptr, &value, &size) != ERROR_SUCCESS) {
    return false;
  }
  return value != 0;
}

void FlutterWindow::SetLaunchMiniSetting(bool on) {
  DWORD value = on ? 1 : 0;
  ::RegSetKeyValueW(HKEY_CURRENT_USER, kRewampRegKey, L"LaunchMini", REG_DWORD,
                    &value, sizeof(value));
}
