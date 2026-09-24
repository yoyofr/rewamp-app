import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var fsChannel: FlutterMethodChannel?

  // « Toujours au premier plan » dans le menu Fenêtre. Le RÉGLAGE Dart fait
  // foi: un clic ne change RIEN ici, il demande à Dart de basculer le réglage,
  // et c'est Dart qui renvoie la coche (et le libellé traduit). Deux états à
  // tenir synchrones sinon — la coche du menu et l'interrupteur de Réglages.
  private var menuChannel: FlutterMethodChannel?
  private var onTopItem: NSMenuItem?

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

    // Canal À PART: `rewamp/window` a déjà un handler côté Dart (plein écran,
    // player_screen), et un canal n'en porte qu'UN — le partager ferait
    // écraser l'un par l'autre selon l'ordre de montage.
    let mch = FlutterMethodChannel(
      name: "rewamp/window_menu",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    mch.setMethodCallHandler { [weak self] call, result in
      if call.method == "setAlwaysOnTop",
         let args = call.arguments as? [String: Any] {
        if let title = args["title"] as? String { self?.onTopItem?.title = title }
        if let on = args["checked"] as? Bool { self?.onTopItem?.state = on ? .on : .off }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.menuChannel = mch
    installAlwaysOnTopMenuItem()
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

  private func installAlwaysOnTopMenuItem() {
    // Le menu « Fenêtre » du MainMenu.xib; à défaut, celui que AppKit connaît.
    guard let menu = NSApp.windowsMenu
      ?? NSApp.mainMenu?.items.last(where: { $0.submenu != nil })?.submenu
    else { return }
    let item = NSMenuItem(
      title: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
    item.target = self
    // En tête du menu, avant Réduire/Zoom: AppKit ajoute la liste des fenêtres
    // en QUEUE, un élément posé à la fin se retrouverait noyé dedans.
    menu.insertItem(item, at: 0)
    menu.insertItem(NSMenuItem.separator(), at: 1)
    onTopItem = item
  }

  @objc private func toggleAlwaysOnTop() {
    menuChannel?.invokeMethod("toggleAlwaysOnTop", arguments: nil)
  }

  @objc private func fsChanged() {
    fsChannel?.invokeMethod(
      "onFullScreenChanged", arguments: styleMask.contains(.fullScreen))
  }
}
