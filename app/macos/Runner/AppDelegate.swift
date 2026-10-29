import Cocoa
import IOKit.pwr_mgt
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {
  /// Paths handed to us by macOS and not yet collected by Dart.
  ///
  /// This buffer is the whole point of the class. `application(_:open:)` fires
  /// for a drop on the Dock icon, for "Open With" in the Finder, and for a
  /// double-clicked file — and on a COLD start it fires while the Flutter
  /// engine is still coming up, long before any Dart code is listening. A
  /// method call sent then is dropped on the floor and the files are lost.
  ///
  /// So nothing is ever pushed. The paths accumulate here, Dart PULLS them with
  /// `takePending` once it is ready, and `filesAvailable` is only a nudge for
  /// the app-already-running case. Pull, not push, is what makes this race-free:
  /// there is no window in which a message can arrive before a listener exists.
  private var pending: [String] = []
  private var channel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  // ── Ligne de commande (lib/cli_options.dart) ─────────────────────────────
  //
  // `Rewamp.app/Contents/MacOS/rewamp [OPTIONS] [FICHIERS]`. Dart interprète
  // TOUT (une règle écrite deux fois diverge); ici on ne décide que ce qui
  // doit l'être avant que Dart n'existe — `--help`, `--version`, « commande
  // de pilotage sans instance » — d'après `assets/cli/cli_manifest.json`,
  // GÉNÉRÉ depuis la table Dart.
  //
  // Transport vers une instance qui tourne: une URL `rewamp://cli?…` envoyée
  // au bundle EXACT de cette instance. ⚠️ Pas `NSWorkspace.open(fichiers)`:
  // sous le bac à sable, l'émetteur ne peut transmettre que ce qu'il sait
  // LIRE (permErr -54 hors ~/Downloads, mesuré le 2026-10-28). C'est
  // l'exception de lecture seule des entitlements (dossier personnel +
  // /Volumes) qui permet à l'instance principale d'ouvrir le chemin nu — et
  // les compagnons d'un module, que l'accès par fichier ne couvrait pas.
  //
  // ⚠️ N'importe quelle page web peut ouvrir `rewamp://`: une URL qui porte
  // des CHEMINS doit porter le jeton `t`, écrit par l'instance principale
  // dans NOTRE conteneur (que la seconde instance partage, une page non).
  // Sans lui Dart n'y prend que le pilotage.

  static let cliScheme = "rewamp"

  /// Lignes de commande pas encore tirées par Dart (`rewamp/cli`
  /// `takePending`): `{args, cwd, trusted}`. STATIQUE: celle d'un démarrage à
  /// froid est posée depuis `MainFlutterWindow.awakeFromNib`, avant que le
  /// délégué ne soit relié au moteur.
  static var pendingCli: [[String: Any]] = []

  /// Démarrage à froid avec `--mini`: la fenêtre naît INVISIBLE et Dart la
  /// révèle une fois rétrécie (`rewamp/cli` `revealWindow`) — sinon on la
  /// voyait en grand une fraction de seconde. Opacité 0 et pas `orderOut`:
  /// une fenêtre jamais affichée risque de ne recevoir aucune image (pas
  /// d'écran, pas de vsync), et le mini lecteur ne serait pas dessiné quand
  /// elle apparaît. Filet: révélée d'office au bout de 5 s.
  static var launchHidden = false

  /// Réglage « Au démarrage: mini lecteur » (ou « comme à la fermeture »),
  /// CONFIÉ par Dart (`setLaunchMini`, lib/launch_window.dart): il doit être
  /// connu ici, avant que Dart n'existe. Clé à part des `flutter.*` de
  /// shared_preferences, qui sont à Dart.
  static let launchMiniKey = "rewampLaunchMini"

  static func revealLaunchWindow() {
    guard launchHidden else { return }
    launchHidden = false
    for w in NSApp.windows where w is MainFlutterWindow { w.alphaValue = 1 }
  }
  private var cliChannel: FlutterMethodChannel?

  struct CliManifest {
    let help: String
    let valued: Set<String>
    let remote: Set<String>
  }

  static func loadCliManifest() -> CliManifest? {
    guard let fw = Bundle.main.privateFrameworksURL else { return nil }
    let url = fw.appendingPathComponent(
      "App.framework/Resources/flutter_assets/assets/cli/cli_manifest.json")
    guard let data = try? Data(contentsOf: url),
          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let opts = obj["options"] as? [[String: Any]]
    else { return nil }
    var valued = Set<String>(), remote = Set<String>()
    for o in opts {
      guard let name = o["name"] as? String else { continue }
      if o["value"] as? Bool == true { valued.insert(name) }
      if o["remote"] as? Bool == true { remote.insert(name) }
    }
    return CliManifest(help: obj["help"] as? String ?? "", valued: valued, remote: remote)
  }

  /// Ce que la ligne demande, au sens du manifeste: les options nommées et le
  /// nombre d'arguments POSITIONNELS (les fichiers). Mêmes règles de forme
  /// que `parseCommandLine` (valeur suivante, `--`, réglages Cocoa `-NSFoo
  /// YES` qui emportent leur valeur).
  static func scanCommandLine(_ args: [String], _ m: CliManifest?)
    -> (names: Set<String>, positional: Int) {
    var names = Set<String>()
    var positional = 0
    var onlyFiles = false
    var i = 0
    while i < args.count {
      let a = args[i]
      i += 1
      if a.isEmpty { continue }
      if onlyFiles { positional += 1; continue }
      if a == "--" { onlyFiles = true; continue }
      if a.hasPrefix("--") {
        let body = a.dropFirst(2)
        let name = String(body.split(separator: "=", maxSplits: 1).first ?? "")
        names.insert(name)
        if m?.valued.contains(name) == true, !body.contains("="),
           i < args.count, !args[i].hasPrefix("-") { i += 1 }
        continue
      }
      if a.hasPrefix("-") && a.count > 1 {
        if a.dropFirst().first?.isUppercase == true,
           i < args.count, !args[i].hasPrefix("-") { i += 1 }
        continue
      }
      positional += 1
    }
    return (names, positional)
  }

  /// Une autre instance de l'app, ou nil.
  static func runningInstance() -> NSRunningApplication? {
    let me = ProcessInfo.processInfo.processIdentifier
    let myId = Bundle.main.bundleIdentifier
    let myBundle = Bundle.main.bundleURL.standardizedFileURL.path
    let myExe = Bundle.main.executableURL?.standardizedFileURL.path
    // ⚠️ Pas `runningApplications(withBundleIdentifier:)` seul: une instance
    // lancée par `flutter run` est enregistrée SANS identifiant de bundle
    // (lsappinfo: `bundleID=[ NULL ]`, mesuré le 2026-10-27), et la recherche
    // ne la voyait pas — la seconde démarrait quand même. Le même BUNDLE ou le
    // même EXÉCUTABLE désigne aussi « nous ».
    return NSWorkspace.shared.runningApplications.first(where: { app in
      guard app.processIdentifier != me else { return false }
      if let id = myId, app.bundleIdentifier == id { return true }
      if app.bundleURL?.standardizedFileURL.path == myBundle { return true }
      if let exe = myExe, app.executableURL?.standardizedFileURL.path == exe {
        return true
      }
      return false
    })
  }

  static var cliTokenURL: URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?.appendingPathComponent("cli_token")
  }

  /// Instance PRINCIPALE: un jeton neuf à chaque lancement.
  static func writeCliToken() -> String? {
    guard let url = cliTokenURL else { return nil }
    var bytes = [UInt8](repeating: 0, count: 24)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess
    else { return nil }
    let token = bytes.map { String(format: "%02x", $0) }.joined()
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    do {
      try token.write(to: url, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    } catch { return nil }
    return token
  }

  static func readCliToken() -> String? {
    guard let url = cliTokenURL else { return nil }
    return (try? String(contentsOf: url, encoding: .utf8))?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static var cliToken: String?

  /// La ligne de commande, AVANT toute vue Flutter (appelé depuis
  /// `MainFlutterWindow.awakeFromNib`; la nib se charge avant
  /// `applicationWillFinishLaunching`). Rend un code de sortie quand ce
  /// processus doit s'arrêter là, nil quand il devient l'instance principale.
  static func handleCommandLine() -> Int32? {
    let args = Array(CommandLine.arguments.dropFirst())
    let manifest = loadCliManifest()
    let (names, positional) = scanCommandLine(args, manifest)
    // Lancé depuis un terminal, stdout y arrive (vérifié le 2026-10-28).
    if names.contains("help") {
      print(versionLine())
      print("")
      print(manifest?.help ?? "Usage: rewamp [OPTIONS] [FILES...]", terminator: "")
      return 0
    }
    if names.contains("version") {
      print(versionLine())
      return 0
    }
    let remoteOnly = positional == 0 && !names.isDisjoint(with: manifest?.remote ?? [])
    let meaningful = positional > 0 || !names.isEmpty
    if let other = runningInstance() {
      guard meaningful, let appURL = other.bundleURL else {
        other.activate(options: [])
        return 0
      }
      var c = URLComponents()
      c.scheme = cliScheme
      c.host = "cli"
      var q = [URLQueryItem(name: "cwd", value: FileManager.default.currentDirectoryPath)]
      if let t = readCliToken() { q.append(URLQueryItem(name: "t", value: t)) }
      q += args.map { URLQueryItem(name: "a", value: $0) }
      c.queryItems = q
      guard let url = c.url else { return 1 }
      let cfg = NSWorkspace.OpenConfiguration()
      // Piloter la lecture ne doit pas voler le premier plan; ouvrir des
      // fichiers, si (comme un double-clic).
      cfg.activates = !remoteOnly
      let done = DispatchSemaphore(value: 0)
      var failed = false
      NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: cfg) { _, err in
        if let err = err {
          failed = true
          FileHandle.standardError.write("rewamp: \(err.localizedDescription)\n".data(using: .utf8)!)
        }
        done.signal()
      }
      _ = done.wait(timeout: .now() + 5)
      return failed ? 1 : 0
    }
    if remoteOnly {
      FileHandle.standardError.write("rewamp: Rewamp is not running.\n".data(using: .utf8)!)
      return 1
    }
    // Instance principale.
    cliToken = writeCliToken()
    // Même règle que `planLaunch` (lib/local_open.dart): `--mini`, ou le
    // réglage sans `--window`.
    launchHidden = names.contains("mini") ||
      (!names.contains("window") && UserDefaults.standard.bool(forKey: launchMiniKey))
    if !args.isEmpty {
      pendingCli.append([
        "args": args,
        "cwd": FileManager.default.currentDirectoryPath,
        "trusted": true,
      ])
    }
    return nil
  }

  static func versionLine() -> String {
    let info = Bundle.main.infoDictionary
    let v = info?["CFBundleShortVersionString"] as? String ?? "?"
    let b = info?["CFBundleVersion"] as? String ?? "?"
    return "Rewamp \(v) (\(b))"
  }

  /// `rewamp://cli?cwd=…&t=…&a=…&a=…` — à la file, Dart prévenu.
  private func receiveCliURL(_ url: URL) {
    guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
          c.host == "cli" else { return }
    let items = c.queryItems ?? []
    let args = items.filter { $0.name == "a" }.compactMap { $0.value }
    guard !args.isEmpty else { return }
    let cwd = items.first { $0.name == "cwd" }?.value ?? NSHomeDirectory()
    let token = items.first { $0.name == "t" }?.value
    let trusted = token != nil && token == AppDelegate.cliToken
    AppDelegate.pendingCli.append(["args": args, "cwd": cwd, "trusted": trusted])
    cliChannel?.invokeMethod("argsAvailable", arguments: nil)
  }

  func attachCli(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "rewamp/cli", binaryMessenger: messenger)
    ch.setMethodCallHandler { call, result in
      switch call.method {
      case "takePending":
        let out = AppDelegate.pendingCli
        AppDelegate.pendingCli.removeAll()
        result(out)
      case "revealWindow":
        AppDelegate.revealLaunchWindow()
        result(nil)
      case "setLaunchMini":
        UserDefaults.standard.set(call.arguments as? Bool ?? false,
                                  forKey: AppDelegate.launchMiniKey)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    cliChannel = ch
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Called by MainFlutterWindow once the engine exists.
  func attachOpenFiles(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "rewamp/open_files", binaryMessenger: messenger)
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "takePending":
        // Atomic hand-over: returning and clearing in one step means a file
        // arriving mid-flight is either in this batch or in the next nudge —
        // never in both, never in neither.
        let out = self.pending
        self.pending.removeAll()
        result(out)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = ch
    // Files may already be waiting: a cold start caused BY a file gets here
    // with the buffer full. Tell Dart to come and collect them.
    if !pending.isEmpty { ch.invokeMethod("filesAvailable", arguments: nil) }
  }

  // ── Dossiers liés: signets à portée de sécurité (local_roots.dart) ──────
  //
  // Le bac à sable n'accorde l'accès à un dossier choisi que pour la SESSION.
  // Un signet « app-scope » (entitlement files.bookmarks.app-scope) le rend
  // durable: Dart le garde en base64, et au lancement `resolve` rouvre la
  // portée — qui reste ouverte tant que la racine est en service (les URL
  // vivent ici, une portée se referme à `release`).
  private var scopedURLs: [String: URL] = [:]

  func attachBookmarks(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "rewamp/bookmarks", binaryMessenger: messenger)
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "create":
        guard let path = args?["path"] as? String else { result(nil); return }
        let url = URL(fileURLWithPath: path)
        do {
          let data = try url.bookmarkData(options: [.withSecurityScope],
                                          includingResourceValuesForKeys: nil,
                                          relativeTo: nil)
          result(FlutterStandardTypedData(bytes: data))
        } catch {
          result(FlutterError(code: "bookmark", message: "\(error)", details: nil))
        }
      case "resolve":
        guard let data = (args?["bookmark"] as? FlutterStandardTypedData)?.data
        else { result(nil); return }
        var stale = false
        do {
          let url = try URL(resolvingBookmarkData: data,
                            options: [.withSecurityScope],
                            relativeTo: nil,
                            bookmarkDataIsStale: &stale)
          // `false` n'est PAS un échec (règle déjà payée sur iOS): on garde
          // l'URL quoi qu'il en soit, c'est elle qui tient la portée.
          _ = url.startAccessingSecurityScopedResource()
          self.scopedURLs[url.path] = url
          result(["path": url.path, "stale": stale])
        } catch {
          result(FlutterError(code: "bookmark", message: "\(error)", details: nil))
        }
      case "release":
        if let path = args?["path"] as? String, let url = self.scopedURLs.removeValue(forKey: path) {
          url.stopAccessingSecurityScopedResource()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for u in urls where u.scheme == AppDelegate.cliScheme { receiveCliURL(u) }
    let paths = urls.filter { $0.isFileURL }.map { $0.path }
    guard !paths.isEmpty else { return }
    pending.append(contentsOf: paths)
    channel?.invokeMethod("filesAvailable", arguments: nil)
  }

  // ── Track-change notifications (optional, Réglages → Lecture) ──────────────
  //
  // One FIXED identifier: each track REPLACES the previous banner instead of
  // stacking one notification per song in the Centre de notifications.
  // Authorization is requested lazily on the first post; when denied, later
  // posts are silent no-ops (the add() just fails), never a prompt loop.
  private var notifAuthRequested = false

  // Keep the display awake while a visualizer is up (see ScreenWakelock).
  // IOKit power assertion rather than a timer nudge: it is the documented way,
  // it names itself in `pmset -g assertions` so a stuck hold is diagnosable,
  // and releasing is impossible to get wrong (one id, released and cleared).
  // NoDisplaySleep, not NoIdleSleep — the machine may still idle-sleep on its
  // own terms, we only ask that the panel stay lit.
  private var sleepAssertion: IOPMAssertionID = 0

  func attachWakelock(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "rewamp/wakelock", binaryMessenger: messenger)
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      guard call.method == "set" else { result(FlutterMethodNotImplemented); return }
      let on = (call.arguments as? [String: Any])?["on"] as? Bool ?? false
      if on {
        guard self.sleepAssertion == 0 else { result(nil); return }
        var id: IOPMAssertionID = 0
        IOPMAssertionCreateWithName(
          kIOPMAssertionTypeNoDisplaySleep as CFString,
          IOPMAssertionLevel(kIOPMAssertionLevelOn),
          "Rewamp visualizer" as CFString,
          &id)
        self.sleepAssertion = id
      } else if self.sleepAssertion != 0 {
        IOPMAssertionRelease(self.sleepAssertion)
        self.sleepAssertion = 0
      }
      result(nil)
    }
  }

  func attachTrackNotify(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "rewamp/notify", binaryMessenger: messenger)
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "track":
        let args    = call.arguments as? [String: Any]
        let title   = args?["title"]   as? String ?? ""
        let artist  = args?["artist"]  as? String ?? ""
        let artwork = args?["artwork"] as? String ?? ""
        self.postTrackNotification(title: title, artist: artist, artworkPath: artwork)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func postTrackNotification(title: String, artist: String, artworkPath: String) {
    let center = UNUserNotificationCenter.current()
    let post = {
      let content = UNMutableNotificationContent()
      content.title = title
      if !artist.isEmpty { content.body = artist }
      // Pochette (ou placeholder par plateforme) résolue côté Dart.
      // ⚠️ UNNotificationAttachment DÉPLACE le fichier dans son magasin —
      // attacher l'original consommerait la pochette du cache. Copie
      // temporaire d'abord; le système possède ensuite la copie.
      if !artworkPath.isEmpty, FileManager.default.fileExists(atPath: artworkPath) {
        let ext = (artworkPath as NSString).pathExtension.isEmpty
          ? "png" : (artworkPath as NSString).pathExtension
        let tmp = FileManager.default.temporaryDirectory
          .appendingPathComponent("rewamp-notif-\(UUID().uuidString).\(ext)")
        do {
          try FileManager.default.copyItem(
            at: URL(fileURLWithPath: artworkPath), to: tmp)
          let att = try UNNotificationAttachment(
            identifier: "artwork", url: tmp, options: nil)
          content.attachments = [att]
        } catch {
          // Sans image plutôt que sans notification.
        }
      }
      let req = UNNotificationRequest(
        identifier: "rewamp.nowplaying", content: content, trigger: nil)
      center.removeDeliveredNotifications(withIdentifiers: ["rewamp.nowplaying"])
      center.add(req)
    }
    if notifAuthRequested {
      post()
    } else {
      notifAuthRequested = true
      center.requestAuthorization(options: [.alert]) { granted, _ in
        if granted { post() }
      }
    }
  }
}
