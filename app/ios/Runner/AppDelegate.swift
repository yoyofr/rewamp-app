import Flutter
import UIKit
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Channel kept alive for its lifetime + active background tasks by id.
  private var bgChannel: FlutterMethodChannel?
  private var bgTasks: [Int: UIBackgroundTaskIdentifier] = [:]
  private var bgCounter = 0

  // Hidden AVRoutePickerView whose internal button we trigger from Dart —
  // the picker routes the whole AVAudioSession, which is what miniaudio
  // plays through, so no AVPlayer is needed. Kept in the hierarchy (the
  // picker refuses to present from a detached view); positioned at the
  // Flutter button's rect so the iPad popover anchors correctly.
  private var routePicker: AVRoutePickerView?
  private var routeChannel: FlutterMethodChannel?

  // NOTE: the AVAudioSession category (.playback) + background activation are now
  // owned by audio_service (see media_session.dart). UIBackgroundModes=audio stays
  // in Info.plist. We only keep the beginBackgroundTask bridge below for downloads.

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // beginBackgroundTask bridge so Dart downloads keep running briefly after the
    // app is backgrounded without audio playing (see background_task.dart).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RewampBackground") {
      let channel = FlutterMethodChannel(
        name: "rewamp/background", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        switch call.method {
        case "begin":
          self.bgCounter += 1
          let id = self.bgCounter
          var taskId = UIBackgroundTaskIdentifier.invalid
          taskId = UIApplication.shared.beginBackgroundTask(withName: "rewamp-download") {
            // Expiration handler: must end the task or iOS kills the app.
            UIApplication.shared.endBackgroundTask(taskId)
            self.bgTasks[id] = nil
          }
          self.bgTasks[id] = taskId
          result(id)
        case "end":
          if let id = call.arguments as? Int, let t = self.bgTasks[id] {
            UIApplication.shared.endBackgroundTask(t)
            self.bgTasks[id] = nil
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.bgChannel = channel
    }

    // Keep the display awake while a visualizer is up (see ScreenWakelock).
    // isIdleTimerDisabled must be touched on the main thread; a channel handler
    // already runs there, but DispatchQueue.main.async makes that explicit and
    // survives the day someone calls this from a background isolate's reply.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RewampWakelock") {
      let channel = FlutterMethodChannel(
        name: "rewamp/wakelock", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "set" else { result(FlutterMethodNotImplemented); return }
        let on = (call.arguments as? [String: Any])?["on"] as? Bool ?? false
        DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = on }
        result(nil)
      }
    }

    // Audio route picker (AirPlay / Bluetooth) — see routePicker above.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RewampRoutePicker") {
      let channel = FlutterMethodChannel(
        name: "rewamp/route_picker", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        guard call.method == "show" else { result(FlutterMethodNotImplemented); return }
        // .windows is deprecated (iOS 15) but the target is 13 — the scene
        // .keyWindow accessor doesn't exist there.
        let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
          ?? UIApplication.shared.windows.first
        guard let root = window?.rootViewController?.view else {
          result(false); return
        }
        let picker = self.routePicker ?? {
          let p = AVRoutePickerView()
          p.alpha = 0.02          // invisible but still "displayed" for UIKit
          p.isUserInteractionEnabled = false
          self.routePicker = p
          return p
        }()
        if picker.superview !== root { root.addSubview(picker) }
        if let args = call.arguments as? [String: Any],
           let x = args["x"] as? Double, let y = args["y"] as? Double,
           let w = args["w"] as? Double, let h = args["h"] as? Double {
          picker.frame = CGRect(x: x, y: y, width: w, height: h)
        } else {
          picker.frame = CGRect(x: root.bounds.midX - 22,
                                y: root.bounds.maxY - 88, width: 44, height: 44)
        }
        // The picker's UI is its internal button — trigger it.
        for sub in picker.subviews {
          if let btn = sub as? UIButton {
            btn.sendActions(for: .touchUpInside)
            result(true)
            return
          }
        }
        result(false)
      }
      self.routeChannel = channel
    }
  }
}
