import Flutter
import UIKit
import AVKit
import MediaPlayer
import UniformTypeIdentifiers

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

  // ── Fichiers ouverts DEPUIS L'EXTÉRIEUR (Fichiers → « Ouvrir avec ») ───────
  //
  // Chemins qu'iOS nous a donnés et que Dart n'a pas encore ramassés.
  //
  // Ce tampon EST le mécanisme. `application(_:open:options:)` se déclenche
  // aussi sur un démarrage à FROID, pendant que le moteur Flutter monte encore
  // — bien avant qu'un `MethodChannel` ait un auditeur. Un message envoyé là
  // tombe dans le vide et le fichier est perdu.
  //
  // Donc on ne POUSSE jamais: les chemins s'accumulent ici, Dart les TIRE avec
  // `takePending`, et `filesAvailable` n'est qu'un coup de coude pour le cas
  // « l'app tournait déjà ». Tirer plutôt que pousser, c'est ce qui supprime la
  // course: il n'existe aucune fenêtre où un message précède son auditeur.
  // Même discipline que macOS, dont ceci est le portage.
  private var pendingOpen: [String] = []
  private var openFilesChannel: FlutterMethodChannel?

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

    // Fichiers ouverts depuis l'extérieur — voir `pendingOpen`.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RewampOpenFiles") {
      let channel = FlutterMethodChannel(
        name: "rewamp/open_files", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        guard call.method == "takePending" else {
          result(FlutterMethodNotImplemented); return
        }
        // Passation ATOMIQUE: rendre et vider d'un seul geste, pour qu'un
        // fichier arrivant en vol soit dans ce lot ou dans le coup de coude
        // suivant — jamais dans les deux, jamais dans aucun.
        let out = self.pendingOpen
        self.pendingOpen.removeAll()
        result(out)
      }
      self.openFilesChannel = channel
      // Des fichiers peuvent DÉJÀ attendre: un démarrage à froid causé par un
      // fichier arrive ici le tampon plein.
      if !pendingOpen.isEmpty { channel.invokeMethod("filesAvailable", arguments: nil) }
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

    // ── État de lecture du centre d'informations (MPNowPlayingInfoCenter) ──
    //
    // `audio_service` ne pose `MPNowPlayingInfoCenter.playbackState` que sur
    // macOS (`#if TARGET_OS_OSX` dans AudioServicePlugin.m): sur iOS il se
    // contente d'écrire `MPNowPlayingInfoPropertyPlaybackRate` dans le
    // dictionnaire. Or c'est `playbackState` qui décide du GLYPHE de l'écran
    // verrouillé pour une app qui ne joue pas par AVPlayer — et sans lui iOS
    // considère l'app comme « en lecture » dès que le dictionnaire est
    // renseigné. D'où le symptôme: au lancement, la piste restaurée armait le
    // mini-lecteur, personne ne jouait, et l'écran verrouillé affichait PAUSE.
    //
    // On pose donc la propriété nous-mêmes, à chaque changement d'état.
    // Complément, pas contournement: le rate écrit par le plugin reste juste,
    // il ne suffit simplement plus.
    if let registrar =
        engineBridge.pluginRegistry.registrar(forPlugin: "RewampNowPlaying") {
      let channel = FlutterMethodChannel(
        name: "rewamp/now_playing", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "setPlaybackState" else {
          result(FlutterMethodNotImplemented); return
        }
        let playing =
          (call.arguments as? [String: Any])?["playing"] as? Bool ?? false
        // MPNowPlayingInfoCenter veut le fil principal.
        DispatchQueue.main.async {
          let center = MPNowPlayingInfoCenter.default()
          center.playbackState = playing ? .playing : .paused
          #if DEBUG
          // Le RATE est ce que le plugin écrit de son côté: le voir ici dit
          // laquelle des deux sources l'écran verrouillé a suivie.
          let rate = center.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate]
          print("[nowplaying] playbackState=\(playing ? "playing" : "paused") "
              + "rate=\(String(describing: rate)) "
              + "hasInfo=\(center.nowPlayingInfo != nil)")
          #endif
        }
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

    // Sélecteur de DOSSIER — le nôtre, pas celui de `file_picker`.
    //
    // ⚠️ Deux choses manquent à celui du greffon sur iOS, et chacune suffit à
    // faire « rien ne se passe »:
    //  - il construit le panneau avec l'API DÉPRÉCIÉE
    //    (`initWithDocumentTypes:@[@"public.folder"] inMode:Open`); depuis iOS
    //    14 le bon constructeur est `forOpeningContentTypes: [.folder]`, et
    //    l'ancien laisse un bouton « Ouvrir » qui ne valide rien;
    //  - il ne prend JAMAIS la portée de sécurité. Un dossier choisi hors du
    //    bac à sable n'est lisible qu'entre
    //    `startAccessingSecurityScopedResource()` et son `stop`: sans elle,
    //    l'énumération rend zéro fichier — un import « réussi » et vide.
    //
    // D'où deux méthodes: `pick` ouvre la portée et rend le chemin, `release`
    // la referme. C'est l'APPELANT Dart qui décide quand relâcher, parce que
    // c'est lui qui copie — la portée doit tenir pendant toute la copie.
    if let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "RewampFolderPicker") {
      let channel = FlutterMethodChannel(
        name: "rewamp/folder_picker", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        switch call.method {
        case "pick":
          self.presentFolderPicker(result)
        case "release":
          self.releaseFolderScope()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.folderChannel = channel
    }
  }

  // ── Sélecteur de dossier (portée de sécurité) ─────────────────────────────

  private var folderChannel: FlutterMethodChannel?
  private var folderResult: FlutterResult?
  /// URL dont la portée est OUVERTE. Une seule à la fois: un second `pick`
  /// referme la précédente, sinon la portée fuit jusqu'à la fin du processus.
  private var scopedFolder: URL?

  private func presentFolderPicker(_ result: @escaping FlutterResult) {
    releaseFolderScope()
    folderResult = result
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [.folder], asCopy: false)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    picker.presentationController?.delegate = self
    let window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
    guard let root = window?.rootViewController else {
      folderResult = nil
      result(nil)
      return
    }
    root.present(picker, animated: true)
  }

  private func releaseFolderScope() {
    scopedFolder?.stopAccessingSecurityScopedResource()
    scopedFolder = nil
  }

  // ── Réception d'un fichier ────────────────────────────────────────────────

  /// Filet pour un cycle de vie SANS scènes.
  ///
  /// ⚠️ Tant qu'Info.plist déclare un `UISceneDelegateClassName`, UIKit ne
  /// passe JAMAIS par ici — les URL vont à `SceneDelegate`, et c'est là que le
  /// vrai chemin vit. Ce override ne coûte rien et redevient le bon point
  /// d'entrée le jour où le gabarit Flutter retire les scènes (il les a
  /// ajoutées récemment); le laisser évite de rejouer le même diagnostic.
  ///
  /// On teste `isFileURL` AVANT de passer la main: c'est le seul cas qui nous
  /// appartient, et il est sans ambiguïté. Tout le reste (schémas d'URL des
  /// greffons — retours OAuth, `url_launcher`) va à `super`, qui les distribue
  /// aux greffons enregistrés.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.isFileURL {
      ingestOpenedFile(url)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  /// Recopie le fichier DANS notre bac à sable et met son chemin en attente.
  ///
  /// ⚠️ La copie n'est pas une précaution, c'est une NÉCESSITÉ. Avec
  /// `LSSupportsOpeningDocumentsInPlace`, iOS peut nous remettre une URL « en
  /// place », hors de notre bac à sable, dont l'accès n'est ouvert que le temps
  /// d'une portée explicite (`startAccessingSecurityScopedResource`). Or nos
  /// décodeurs sont en C: ils ouvrent le CHEMIN plus tard, sur le fil
  /// producteur, longtemps après la fin de cette portée — ils liraient un
  /// fichier qu'ils n'ont plus le droit d'ouvrir. Quand iOS a déjà copié dans
  /// `Documents/Inbox/`, la portée n'est pas nécessaire et l'appel échoue sans
  /// dommage: on copie de la même façon, un seul chemin de code.
  func ingestOpenedFile(_ url: URL) {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let fm = FileManager.default
    guard var dir = try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil, create: true)
    else { return }
    dir.appendPathComponent("opened", isDirectory: true)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    excludeFromBackup(dir)

    let dest = dir.appendingPathComponent(url.lastPathComponent)
    do {
      // Même nom = même fichier rouvert: on remplace, sinon la copie échoue et
      // le geste ne fait rien la deuxième fois.
      if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
      try fm.copyItem(at: url, to: dest)
    } catch {
      return
    }

    // ⚠️ Quand le document n'est PAS ouvert « en place », iOS en a fait une
    // copie dans `Documents/Inbox/` et c'est ELLE qu'on vient de recevoir.
    // Cette copie est à NOUS: Apple documente que l'app doit l'effacer une fois
    // le fichier consommé, et personne d'autre ne le fera. Laissée là, elle
    // s'accumule à chaque « Ouvrir avec » — dans `Documents`, donc sauvegardée
    // dans iCloud ET visible dans Fichiers, sans que l'utilisateur ait de quoi
    // faire le lien. On ne touche évidemment QUE ce qui est dans notre Inbox.
    if url.path.contains("/Documents/Inbox/") { try? fm.removeItem(at: url) }

    pendingOpen.append(dest.path)
    openFilesChannel?.invokeMethod("filesAvailable", arguments: nil)
  }

  /// `opened/` est un cache de fichiers de l'UTILISATEUR: il les a déjà
  /// ailleurs, et les remonter dans iCloud serait payer deux fois le même
  /// octet. (Apple rejette d'ailleurs les apps qui sauvegardent du
  /// re-téléchargeable.)
  private func excludeFromBackup(_ dir: URL) {
    var url = dir
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
  }

}

// MARK: - Sélecteur de dossier

extension AppDelegate: UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  func documentPicker(_ controller: UIDocumentPickerViewController,
                      didPickDocumentsAt urls: [URL]) {
    guard let result = folderResult else { return }
    folderResult = nil
    guard let url = urls.first else { result(nil); return }
    // La portée reste OUVERTE jusqu'au `release` de l'appelant: c'est pendant
    // ce temps-là que Dart énumère et copie.
    //
    // ⚠️ `false` ne veut PAS dire « échec »: une URL DÉJÀ accessible n'est pas
    // security-scoped et le refuse — c'est exactement le cas d'un dossier pris
    // dans « Sur mon iPhone / rewamp », le plus courant. Abandonner ici
    // aurait rendu le sélecteur inerte précisément là où il n'y avait rien à
    // demander. On ne mémorise alors aucune portée à relâcher.
    if url.startAccessingSecurityScopedResource() {
      scopedFolder = url
    }
    result(url.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    folderResult?(nil)
    folderResult = nil
  }

  // Panneau écarté par un glissement: le delegate ci-dessus n'est pas appelé,
  // et sans ça la promesse Dart n'aboutit jamais (le bouton reste inerte pour
  // toujours).
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    folderResult?(nil)
    folderResult = nil
  }
}
