import Flutter
import Intents
import UIKit

enum SiriDiagnostics {
  private static let queue = DispatchQueue(label: "rewamp.siri.diagnostics")
  static let limit = 128 * 1024

  static func record(_ fields: [String: Any]) {
    queue.async {
      do {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory,
          in: .userDomainMask, appropriateFor: nil, create: true)
        try append(fields, to: folder.appendingPathComponent("siri-diagnostics.jsonl"))
      } catch { NSLog("[Siri] diagnostic log unavailable") }
    }
  }

  static func append(_ fields: [String: Any], to url: URL) throws {
    let fm = FileManager.default
    var event = fields
    event["time"] = ISO8601DateFormatter().string(from: Date())
    var data = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
    data.append(10)
    guard data.count < limit else { return }
    let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    if size + data.count > limit {
      let previous = url.appendingPathExtension("previous")
      try? fm.removeItem(at: previous)
      try fm.moveItem(at: url, to: previous)
    }
    if !fm.fileExists(atPath: url.path) {
      fm.createFile(atPath: url.path, contents: nil, attributes: [
        .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        .posixPermissions: 0o600])
      var resource = url
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try resource.setResourceValues(values)
    }
    let file = try FileHandle(forWritingTo: url)
    defer { try? file.close() }
    try file.seekToEnd()
    try file.write(contentsOf: data)
  }
}

enum SiriVocabulary {
  private static var recentArtists: [String] = []
  private static var learnedArtists: [String] = []
  private static var playlists: [String] = []
  static func bounded(_ strings: [String]) -> [String] {
    var seen = Set<String>()
    return strings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && $0.count < 200 && seen.insert($0.lowercased()).inserted }
      .prefix(100).map { $0 }
  }
  static func update(_ fields: [String: Any]) {
    recentArtists = bounded(fields["artists"] as? [String] ?? [])
    playlists = bounded(fields["playlists"] as? [String] ?? [])
    publish()
  }
  static func learn(_ rows: [[String: Any]]) {
    learnedArtists = bounded(rows.flatMap { row in
      row["artists"] as? [String] ?? [row["artist"] as? String ?? ""]
    } + learnedArtists)
    publish()
  }
  private static func publish() {
    guard Bundle.main.object(forInfoDictionaryKey: "RewampCarPlayEnabled") as? String == "1"
    else { return }
    INVocabulary.shared().setVocabularyStrings(
      NSOrderedSet(array: bounded(learnedArtists + recentArtists)), of: .mediaMusicArtistName)
    INVocabulary.shared().setVocabularyStrings(
      NSOrderedSet(array: playlists), of: .mediaPlaylistTitle)
  }
}

// The identifier carries catalogue metadata, never a process-specific action token.
enum SiriMediaReference {
  static let prefix = "rewamp-media:"
  static func identifier(_ row: [String: Any]) -> String? {
    guard let id = row["mediaId"] as? String, !id.isEmpty else { return nil }
    let payload: [String: Any] = ["mediaId": id, "title": row["title"] as? String ?? "",
      "artist": row["artist"] as? String ?? "", "album": row["album"] as? String ?? "",
      "collection": row["collection"] as? String ?? "",
      "playlist": row["playlist"] as? Bool ?? false, "subsong": row["subsong"] as? Int ?? 0]
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    else { return nil }
    return prefix + data.base64EncodedString()
  }
  static func decode(_ identifier: String?) -> [String: Any]? {
    guard let identifier = identifier, identifier.hasPrefix(prefix), identifier.count < 8192,
          let data = Data(base64Encoded: String(identifier.dropFirst(prefix.count))),
          let row = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let id = row["mediaId"] as? String, !id.isEmpty, id.count < 200,
          let title = row["title"] as? String, title.count < 1000 else { return nil }
    return row
  }
  static func sameIdentity(_ a: String?, _ b: String?) -> Bool {
    guard let a = decode(a), let b = decode(b) else { return false }
    return a["mediaId"] as? String == b["mediaId"] as? String &&
      (a["subsong"] as? Int ?? 0) == (b["subsong"] as? Int ?? 0) &&
      (a["playlist"] as? Bool ?? false) == (b["playlist"] as? Bool ?? false)
  }
}

struct SiriMediaRequest {
  var arguments: [String: Any]
  var isEmpty: Bool {
    ["query", "artist", "album"].allSatisfy { (arguments[$0] as? String ?? "").isEmpty }
  }
  init(search: INMediaSearch?, items: [INMediaItem]?, container: INMediaItem? = nil,
       shuffle: Bool = false) {
    let item = items?.first ?? container
    let saved = SiriMediaReference.decode(item?.identifier)
      ?? SiriMediaReference.decode(search?.mediaIdentifier)
    func text(_ value: String?) -> String {
      value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    var query = text(search?.mediaName)
    var artist = text(search?.artistName)
    var album = text(search?.albumName)
    if query.isEmpty { query = text(saved?["title"] as? String ?? item?.title) }
    if artist.isEmpty { artist = text(saved?["artist"] as? String ?? item?.artist) }
    if album.isEmpty { album = text(saved?["album"] as? String) }
    let explicitType = search?.mediaType ?? .unknown
    let fallbackType: INMediaItemType = saved?["playlist"] as? Bool == true ? .playlist : (item?.type ?? .unknown)
    let type = explicitType == .unknown ? fallbackType : explicitType
    if type == .artist { if artist.isEmpty { artist = query }; query = "" }
    if type == .album { if album.isEmpty { album = query }; query = "" }
    arguments = ["query": query, "artist": artist, "album": album,
      "playlist": type == .playlist, "shuffle": shuffle,
      "request": UUID().uuidString, "mediaType": type.rawValue,
      "itemCount": items?.count ?? 0,
      "rawMediaName": text(search?.mediaName), "rawArtist": text(search?.artistName),
      "rawAlbum": text(search?.albumName), "genres": search?.genreNames ?? [],
      "moods": search?.moodNames ?? [], "reference": search?.reference.rawValue ?? 0,
      "sortOrder": search?.sortOrder.rawValue ?? 0,
      "hasItemIdentifier": item?.identifier != nil]
  }
}

enum SiriLookupError: Error, Equatable { case unavailable(String) }

final class RewampMediaIntentHandler: NSObject, INPlayMediaIntentHandling,
    INSearchForMediaIntentHandling {
  typealias Send = (String, [String: Any], @escaping (Any?) -> Void) -> Void
  private let send: Send
  private let log: ([String: Any]) -> Void
  private let remember: ([String: Any]) -> String?
  private let selection: (String) -> [String: Any]?

  init(send: @escaping Send = { method, args, done in
    CarPlayBridge.shared.whenReady(method, args,
      deadline: Date().addingTimeInterval(8), completion: done)
  }, log: @escaping ([String: Any]) -> Void = SiriDiagnostics.record,
       remember: @escaping ([String: Any]) -> String? = { CarPlayBridge.shared.rememberVoiceRow($0) },
       selection: @escaping (String) -> [String: Any]? = { CarPlayBridge.shared.voiceRow($0) }) {
    self.send = send; self.log = log; self.remember = remember; self.selection = selection
  }

  func find(_ request: SiriMediaRequest,
            completion: @escaping (Result<[INMediaItem], SiriLookupError>) -> Void) {
    var fields = request.arguments
    fields["stage"] = "resolve_request"
    fields["carplayConnected"] = CarPlayBridge.shared.scene != nil
    fields["bridgeReady"] = CarPlayBridge.shared.ready
    fields["build"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? ""
    log(fields)
    let started = Date()
    var finished = false
    let finish: (Result<[INMediaItem], SiriLookupError>) -> Void = { [log] result in
      guard !finished else { return }
      finished = true
      var event: [String: Any] = ["request": request.arguments["request"] ?? "",
        "ms": Int(Date().timeIntervalSince(started) * 1000)]
      switch result {
      case .success(let items): event["stage"] = "resolve_result"; event["count"] = items.count
      case .failure(let error): event["stage"] = "resolve_error"; event["error"] = String(describing: error)
      }
      log(event)
      completion(result)
    }
    let timeout = DispatchWorkItem { finish(.failure(.unavailable("timeout"))) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
    send("voiceSearch", request.arguments) { [weak self] value in
      timeout.cancel()
      guard !finished else { return }
      if let error = value as? FlutterError {
        finish(.failure(.unavailable(error.code))); return
      }
      guard let rows = value as? [[String: Any]], let self = self else {
        finish(.failure(.unavailable("invalid_response"))); return
      }
      let items = rows.compactMap { row -> INMediaItem? in
        guard let id = self.remember(row) else { return nil }
        return INMediaItem(identifier: id,
          title: row["spokenTitle"] as? String ?? row["title"] as? String,
          type: row["playlist"] as? Bool == true ? .playlist : .song, artwork: nil,
          artist: row["artist"] as? String)
      }
      if items.count != rows.count {
        finish(.failure(.unavailable("invalid_items"))); return
      }
      SiriVocabulary.learn(rows)
      finish(.success(items))
    }
  }

  func resolveMediaItems(for intent: INPlayMediaIntent,
      with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.resolveMediaItems(for: intent, with: completion) }; return
    }
    let request = SiriMediaRequest(search: intent.mediaSearch, items: intent.mediaItems,
      container: intent.mediaContainer, shuffle: intent.playShuffled == true)
    guard !request.isEmpty else {
      var event = request.arguments
      event["stage"] = "empty_request"
      log(event)
      completion([.needsValue()]); return
    }
    find(request) { result in
      switch result {
      case .failure: completion([.unsupported(forReason: .serviceUnavailable)])
      case .success(let items):
        let selected = intent.mediaItems?.first?.identifier ?? intent.mediaSearch?.mediaIdentifier
        if SiriMediaReference.decode(selected) != nil {
          if let match = items.first(where: { SiriMediaReference.sameIdentity($0.identifier, selected) }) {
            completion([.success(with: match)])
          } else { completion([.unsupported()]) }
        } else if items.isEmpty { completion([.unsupported()]) }
        else if items.count == 1 { completion([.success(with: items[0])]) }
        else { completion([.disambiguation(with: items)]) }
      }
    }
  }

  func handle(intent: INPlayMediaIntent,
              completion: @escaping (INPlayMediaIntentResponse) -> Void) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.handle(intent: intent, completion: completion) }; return
    }
    func play(_ item: INMediaItem) {
      guard let identifier = item.identifier, let row = selection(identifier),
            let token = row["id"] as? String else {
        completion(INPlayMediaIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil)); return
      }
      log(["stage": "play_request", "title": row["title"] ?? "", "mediaId": row["mediaId"] ?? ""])
      send("select", ["source": "voiceSearch", "id": token]) { [log] result in
        let error = result as? FlutterError
        log(["stage": "play_result", "error": error?.code ?? "", "success": error == nil])
        completion(INPlayMediaIntentResponse(code: error == nil ? .success : .failure, userActivity: nil))
      }
    }
    if let item = intent.mediaItems?.first, let identifier = item.identifier,
       selection(identifier) != nil { play(item); return }
    let request = SiriMediaRequest(search: intent.mediaSearch, items: intent.mediaItems,
      container: intent.mediaContainer, shuffle: intent.playShuffled == true)
    guard !request.isEmpty else {
      completion(INPlayMediaIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil)); return
    }
    find(request) { result in
      let selected = intent.mediaItems?.first?.identifier ?? intent.mediaSearch?.mediaIdentifier
      if case .success(let items) = result {
        let match = items.first(where: { SiriMediaReference.sameIdentity($0.identifier, selected) })
        if let item = match ?? (SiriMediaReference.decode(selected) == nil && items.count == 1 ? items.first : nil) {
          play(item); return
        }
      }
      completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
    }
  }

  func handle(intent: INSearchForMediaIntent,
              completion: @escaping (INSearchForMediaIntentResponse) -> Void) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.handle(intent: intent, completion: completion) }; return
    }
    let request = SiriMediaRequest(search: intent.mediaSearch, items: intent.mediaItems)
    find(request) { result in
      switch result {
      case .failure:
        completion(INSearchForMediaIntentResponse(code: .failure, userActivity: nil))
      case .success(let items):
        let response = INSearchForMediaIntentResponse(code: items.isEmpty ? .failure : .success, userActivity: nil)
        response.mediaItems = items
        CarPlayBridge.shared.scene?.showVoiceResults(items)
        completion(response)
      }
    }
  }
}
