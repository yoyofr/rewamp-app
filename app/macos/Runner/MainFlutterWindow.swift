import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var fsChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Launch splash background (#160A1E) so nothing flashes black/white before
    // the first Flutter frame — macOS has no native splash. Matches the intro's
    // background (see splash_intro.dart kSplashBg).
    self.backgroundColor = NSColor(red: 0x16/255.0, green: 0x0A/255.0, blue: 0x1E/255.0, alpha: 1.0)

    // Keep the window usable: below this the player sheet / viz / grids clip.
    self.minSize = NSSize(width: 480, height: 640)

    // Native window fullscreen control for the visualizer's "true fullscreen"
    // button (the in-app one only fills the player sheet).
    let ch = FlutterMethodChannel(
      name: "rewamp/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "toggleFullScreen":
        self.toggleFullScreen(nil)
        result(nil)
      case "isFullScreen":
        result(self.styleMask.contains(.fullScreen))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.fsChannel = ch
    NotificationCenter.default.addObserver(
      self, selector: #selector(fsChanged),
      name: NSWindow.didEnterFullScreenNotification, object: self)
    NotificationCenter.default.addObserver(
      self, selector: #selector(fsChanged),
      name: NSWindow.didExitFullScreenNotification, object: self)

    // Hand the engine to the app delegate so it can serve the files macOS
    // gave us — a Dock drop, "Open With", a double-clicked module. The delegate
    // owns the buffer because it receives those events before this window (and
    // before the engine) exists on a cold start. See AppDelegate.pending.
    (NSApp.delegate as? AppDelegate)?
      .attachOpenFiles(messenger: flutterViewController.engine.binaryMessenger)
    // Track-change notifications (optional setting) — same delegate, own channel.
    (NSApp.delegate as? AppDelegate)?
      .attachTrackNotify(messenger: flutterViewController.engine.binaryMessenger)

    // Display wakelock while a visualizer is up — same delegate, own channel.
    (NSApp.delegate as? AppDelegate)?
      .attachWakelock(messenger: flutterViewController.engine.binaryMessenger)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  @objc private func fsChanged() {
    fsChannel?.invokeMethod(
      "onFullScreenChanged", arguments: styleMask.contains(.fullScreen))
  }
}
