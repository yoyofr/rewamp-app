#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <shellapi.h>

#include <string>
#include <vector>

#include "../../native_cli/rewamp_cli.h"
#ifndef FLUTTER_VERSION
#define FLUTTER_VERSION ""
#endif
#include "flutter_window.h"
#include "media_controls.h"
#include "utils.h"

// Instance UNIQUE. Une seconde invocation (`Rewamp.exe fichier.mod` alors que
// l'app tourne) ne démarre pas un second moteur audio: elle transmet sa ligne
// de commande à la fenêtre existante par WM_COPYDATA, puis se termine.
//
// Les arguments partent BRUTS, précédés de `--cwd=<dossier courant de CETTE
// invocation>` — l'instance principale a le sien, qui n'a rien à voir. Dart
// interprète tout (lib/cli_options.dart).
//
// [remote_only]: une commande de pilotage seule (`--play-pause`) ne ramène pas
// la fenêtre au premier plan — marquée par l'étiquette du message.
static bool ForwardToRunningInstance(bool remote_only) {
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) return false;
  std::string payload;
  wchar_t cwd[MAX_PATH * 4];
  DWORD cn = ::GetCurrentDirectoryW(MAX_PATH * 4, cwd);
  if (cn > 0 && cn < MAX_PATH * 4) {
    payload += "--cwd=" + Utf8FromUtf16(cwd);
    payload.push_back('\0');
  }
  for (int i = 1; i < argc; i++) {   // argv[0] = l'exécutable
    payload += Utf8FromUtf16(argv[i]);
    payload.push_back('\0');
  }
  ::LocalFree(argv);

  // L'instance principale peut être en train de démarrer: sa fenêtre
  // n'existe pas encore. On l'attend un peu plutôt que d'en lancer une autre.
  HWND target = nullptr;
  for (int tries = 0; tries < 50 && target == nullptr; tries++) {
    target = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"rewamp");
    if (target == nullptr) ::Sleep(100);
  }
  if (target == nullptr) return false;

  // Sans ça Windows refuse à la fenêtre cible de passer au premier plan.
  if (!remote_only) {
    DWORD pid = 0;
    ::GetWindowThreadProcessId(target, &pid);
    if (pid != 0) ::AllowSetForegroundWindow(pid);
  }

  COPYDATASTRUCT cds;
  cds.dwData = remote_only ? FlutterWindow::kCliQuietCopyDataTag
                           : FlutterWindow::kCliCopyDataTag;
  cds.cbData = static_cast<DWORD>(payload.size());
  cds.lpData = payload.data();
  DWORD_PTR res = 0;
  return ::SendMessageTimeoutW(target, WM_COPYDATA, 0,
                               reinterpret_cast<LPARAM>(&cds),
                               SMTO_ABORTIFHUNG, 5000, &res) != 0;
}

// Les arguments de CETTE invocation, sans argv[0], en UTF-8.
static std::vector<std::string> CliArgs() {
  std::vector<std::string> out;
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) return out;
  for (int i = 1; i < argc; i++) out.push_back(Utf8FromUtf16(argv[i]));
  ::LocalFree(argv);
  return out;
}

// `<dossier de l'exécutable>\data\flutter_assets\assets\cli\cli_manifest.json`.
static rewamp_cli::Manifest LoadCliManifest() {
  std::wstring exe(MAX_PATH * 4, L'\0');
  DWORD n = ::GetModuleFileNameW(nullptr, exe.data(),
                                 static_cast<DWORD>(exe.size()));
  if (n == 0 || n >= exe.size()) return rewamp_cli::Manifest();
  exe.resize(n);
  size_t slash = exe.find_last_of(L"\\/");
  if (slash == std::wstring::npos) return rewamp_cli::Manifest();
  return rewamp_cli::LoadManifest(
      exe.substr(0, slash) +
      L"\\data\\flutter_assets\\assets\\cli\\cli_manifest.json");
}

// Sortie vers la console du terminal qui a lancé l'exécutable (AttachConsole
// en tête de wWinMain), ou vers le fichier si la sortie est redirigée. ⚠️ Une
// app GUI ne fait pas attendre `cmd.exe`: le texte peut arriver APRÈS l'invite.
static void WriteStd(DWORD which, const std::string& text) {
  HANDLE h = ::GetStdHandle(which);
  bool opened = false;
  if (h == nullptr || h == INVALID_HANDLE_VALUE) {
    h = ::CreateFileW(L"CONOUT$", GENERIC_WRITE, FILE_SHARE_WRITE, nullptr,
                      OPEN_EXISTING, 0, nullptr);
    if (h == INVALID_HANDLE_VALUE) return;
    opened = true;
  }
  DWORD written = 0;
  ::WriteFile(h, text.data(), static_cast<DWORD>(text.size()), &written,
              nullptr);
  if (opened) ::CloseHandle(h);
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Ce que le natif décide AVANT Dart (native_cli/rewamp_cli.h).
  const rewamp_cli::Manifest manifest = LoadCliManifest();
  const rewamp_cli::Scan scan = rewamp_cli::ScanArgs(CliArgs(), manifest);
  if (scan.Has("help")) {
    WriteStd(STD_OUTPUT_HANDLE, rewamp_cli::HelpText(manifest, FLUTTER_VERSION));
    return EXIT_SUCCESS;
  }
  if (scan.Has("version")) {
    WriteStd(STD_OUTPUT_HANDLE, rewamp_cli::VersionLine(FLUTTER_VERSION));
    return EXIT_SUCCESS;
  }
  const bool remote_only = scan.RemoteOnly(manifest);

  // Instance unique (voir ForwardToRunningInstance). Le mutex vit jusqu'à la
  // fin du processus: le système le libère à sa sortie.
  ::CreateMutexW(nullptr, FALSE, L"Local\\app.rewamp.Rewamp.single-instance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS &&
      ForwardToRunningInstance(remote_only)) {
    return EXIT_SUCCESS;
  }
  // Une commande de pilotage seule sans instance: le dire, plutôt que de
  // démarrer l'app pour rien.
  if (remote_only) {
    WriteStd(STD_ERROR_HANDLE, rewamp_cli::kNotRunning);
    return EXIT_FAILURE;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  MediaControls::RegisterAppIdentity();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Même règle que `planLaunch` (lib/local_open.dart): `--mini`, ou le
  // réglage sans `--window`.
  window.set_launch_hidden(scan.Has("mini") ||
                           (!scan.Has("window") &&
                            FlutterWindow::LaunchMiniSetting()));
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"rewamp", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
