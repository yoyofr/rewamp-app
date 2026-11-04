import Flutter
import UIKit
import XCTest
import Intents
@testable import Runner

class RunnerTests: XCTestCase {

  private func item(_ title: String, artist: String, identifier: String? = nil) -> INMediaItem {
    INMediaItem(identifier: identifier, title: title, type: .song, artwork: nil, artist: artist)
  }

  private func row(_ id: String = "modland-song", token: String = "current") -> [String: Any] {
    ["id": token, "mediaId": id, "title": "Durban Poison", "artist": "Randall",
     "collection": id == "modland-song" ? "modland" : "amp", "subsong": 0,
     "playlist": false]
  }

  func testMediaItemFallbackUsesTitleAndArtist() {
    let request = SiriMediaRequest(search: nil, items: [item("Acidland Metropolis", artist: "Booster")])
    XCTAssertFalse(request.isEmpty)
    XCTAssertEqual(request.arguments["query"] as? String, "Acidland Metropolis")
    XCTAssertEqual(request.arguments["artist"] as? String, "Booster")
  }

  func testArtistAndAlbumRequestsUseStructuredFilters() {
    for type in [INMediaItemType.artist, .album] {
      let search = INMediaSearch(mediaType: type, sortOrder: .unknown,
        mediaName: type == .artist ? "Randall" : "Remedy 96", artistName: nil,
        albumName: nil, genreNames: nil, moodNames: nil, releaseDate: nil,
        reference: .unknown, mediaIdentifier: nil)
      let request = SiriMediaRequest(search: search, items: nil)
      XCTAssertEqual(request.arguments["query"] as? String, "")
      XCTAssertEqual(request.arguments[type == .artist ? "artist" : "album"] as? String,
                     type == .artist ? "Randall" : "Remedy 96")
    }
  }

  func testStableReferencesDoNotContainActionTokens() {
    let a = SiriMediaReference.identifier(row(token: "old-token"))!
    let b = SiriMediaReference.identifier(row(token: "new-token"))!
    XCTAssertEqual(a, b)
    XCTAssertFalse(a.contains("old-token"))
    XCTAssertFalse(SiriMediaReference.sameIdentity(a, SiriMediaReference.identifier(row("amp-song"))))
    XCTAssertNil(SiriMediaReference.decode("untrusted:" + a))
  }

  func testSavedReferenceRetainsRawTitleAfterSpokenDisambiguation() {
    let identifier = SiriMediaReference.identifier(row())!
    let request = SiriMediaRequest(search: nil,
      items: [item("Durban Poison (Modland)", artist: "Randall", identifier: identifier)])
    XCTAssertEqual(request.arguments["query"] as? String, "Durban Poison")
  }

  func testIdentifierOnlySearchRestoresQueryMetadata() {
    let search = INMediaSearch(mediaType: .song, sortOrder: .unknown,
      mediaName: nil, artistName: nil, albumName: nil, genreNames: nil,
      moodNames: nil, releaseDate: nil, reference: .unknown,
      mediaIdentifier: SiriMediaReference.identifier(row()))
    let request = SiriMediaRequest(search: search, items: nil)
    XCTAssertEqual(request.arguments["query"] as? String, "Durban Poison")
    XCTAssertEqual(request.arguments["artist"] as? String, "Randall")
  }

  func testEngineRestartDiscardsOldActionTokens() {
    let bridge = CarPlayBridge()
    let identifier = bridge.rememberVoiceRow(row())!
    XCTAssertNotNil(bridge.voiceRow(identifier))
    bridge.resetVoiceSelections()
    XCTAssertNil(bridge.voiceRow(identifier))
  }

  func testIdentifierOnlyPlaylistRetainsItsMediaType() {
    var playlist = row()
    playlist["playlist"] = true
    playlist["title"] = "Road music"
    let search = INMediaSearch(mediaType: .unknown, sortOrder: .unknown,
      mediaName: nil, artistName: nil, albumName: nil, genreNames: nil,
      moodNames: nil, releaseDate: nil, reference: .unknown,
      mediaIdentifier: SiriMediaReference.identifier(playlist))
    let request = SiriMediaRequest(search: search, items: nil)
    XCTAssertEqual(request.arguments["playlist"] as? Bool, true)
    XCTAssertEqual(request.arguments["query"] as? String, "Road music")
  }

  func testNetworkFailureIsNotAnEmptySearchResult() {
    var events: [[String: Any]] = []
    let handler = RewampMediaIntentHandler(send: { _, _, done in
      done(FlutterError(code: "search_unavailable", message: nil, details: nil))
    }, log: { events.append($0) })
    handler.find(SiriMediaRequest(search: nil, items: [item("Durban Poison", artist: "Randall")])) { result in
      guard case .failure(.unavailable("search_unavailable")) = result else {
        XCTFail("Search failures must remain service failures"); return
      }
    }
    XCTAssertEqual(events.last?["stage"] as? String, "resolve_error")
  }

  func testGenuineNoMatchRemainsSuccessfulEmptySearch() {
    let handler = RewampMediaIntentHandler(send: { _, _, done in done([[String: Any]]()) }, log: { _ in })
    handler.find(SiriMediaRequest(search: nil, items: [item("Unknown", artist: "Composer")])) { result in
      guard case .success(let items) = result else { XCTFail("Unexpected service failure"); return }
      XCTAssertTrue(items.isEmpty)
    }
  }

  func testMalformedBridgeResponseIsAServiceFailure() {
    let handler = RewampMediaIntentHandler(send: { _, _, done in done(nil) }, log: { _ in })
    handler.find(SiriMediaRequest(search: nil, items: [item("Durban Poison", artist: "Randall")])) { result in
      guard case .failure(.unavailable("invalid_response")) = result else {
        XCTFail("Malformed responses must not masquerade as no matches"); return
      }
    }
  }

  func testExpiredSelectionResolvesTheSameCatalogueVersionAfterRestart() {
    let saved = SiriMediaReference.identifier(row("amp-song", token: "expired"))!
    var cache: [String: [String: Any]] = [:]
    var selected: String?
    let handler = RewampMediaIntentHandler(send: { method, args, done in
      if method == "voiceSearch" {
        XCTAssertEqual(args["query"] as? String, "Durban Poison")
        done([self.row(token: "new-modland"), self.row("amp-song", token: "new-amp")])
      } else { selected = args["id"] as? String; done(nil) }
    }, log: { _ in }, remember: { row in
      let id = SiriMediaReference.identifier(row)!
      cache[id] = row
      return id
    }, selection: { cache[$0] })
    let intent = INPlayMediaIntent(mediaItems: [item("Durban Poison (AMP)", artist: "Randall", identifier: saved)],
      mediaContainer: nil, playShuffled: false, playbackRepeatMode: .unknown,
      resumePlayback: nil, playbackQueueLocation: .unknown, playbackSpeed: nil, mediaSearch: nil)
    let done = expectation(description: "Selection is recovered")
    handler.handle(intent: intent) { response in
      XCTAssertEqual(response.code, .success)
      done.fulfill()
    }
    wait(for: [done], timeout: 2)
    XCTAssertEqual(selected, "new-amp")
  }

  func testVocabularyIsBoundedAndDeduplicated() {
    XCTAssertEqual(SiriVocabulary.bounded([" Randall ", "randall", "Booster", ""]), ["Randall", "Booster"])
    XCTAssertEqual(SiriVocabulary.bounded((0..<200).map { "Artist \($0)" }).count, 100)
  }

  func testDiagnosticsRotateAndRemainBounded() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("test.jsonl")
    for _ in 0..<150 { try SiriDiagnostics.append(["stage": "test", "query": String(repeating: "x", count: 1000)], to: file) }
    XCTAssertLessThan(try Data(contentsOf: file).count, SiriDiagnostics.limit)
    XCTAssertTrue(FileManager.default.fileExists(atPath: file.appendingPathExtension("previous").path))
  }

}
