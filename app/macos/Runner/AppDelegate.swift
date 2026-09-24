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

  override func application(_ application: NSApplication, open urls: [URL]) {
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
