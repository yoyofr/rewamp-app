# CarPlay audio integration

Rewamp uses Apple's CarPlay framework with the existing iOS 15 minimum.
The car and phone share one Flutter engine, library, queue and audio decoder.
The engine starts in `AppDelegate`, so launching from CarPlay does not require
opening a phone window first. `SceneDelegate` attaches the phone UI to that
same engine when needed.

## Features

- **Queue:** select an entry, including an individual subsong. Selection follows
  the entry's identity if the queue is reordered while the list is visible.
- **Library:** favourites, recent tracks and saved playlists. Catalogue entries
  restored from an account remain downloadable even before a local track row
  exists. Missing files without a catalogue identity are omitted.
- **Browse:** select a catalogue collection and browse its tracks, ordered by
  popularity, with server pagination. Archive albums open their track lists.
- **Search:** Siri media search works on iOS 15+, including the Siri assistant
  row in Browse. Try “Play Ocean Loader in Rewamp” or “Shuffle my Road music
  playlist in Rewamp”; Siri can ask which matching track you mean. Siri search
  results can also open a selectable CarPlay list. On iOS 27+, the magnifying
  glass in Library searches local tracks, Browse searches the full catalogue,
  and a collection's button searches within that collection. The car controls
  when the keyboard is available.
- **Playlists:** Play all starts in playlist order; Shuffle starts a new shuffled
  queue. Both actions cover the complete playlist, including downloadable
  entries and tracks beyond the current display page.
- **Download and play:** the phone's existing resolver handles cached files,
  mirrors, archive albums, auxiliary files and subsongs. Progress, cancellation
  and errors are presented in CarPlay without a phone dialog. Cancellation uses
  a token scoped to the current playback request. The queue is published before
  downloading, and Next/Previous remain available on the progress screen and
  through remote transport controls. Skipping or selecting another track
  cancels the previous request; late results cannot start the skipped track or
  overwrite the newer progress screen. List-row completion happens immediately
  so a long download does not hold CarPlay's selection spinner. Only a genuine
  resolver/download/decoder failure produces an error. Rewamp downloads/cache-fills before
  decoding; this integration does not add progressive network audio streaming.
- **Now Playing:** Apple's shared template uses `audio_service`'s existing
  metadata, artwork, transport commands and interruption handling. A native
  shuffle button toggles the existing queue's shuffle mode on/off, keeping the
  current track playing. Its selected appearance follows the shared shuffle
  state, including changes from the phone and playlists and after reconnect.
  System media shuffle commands use that same state. Up Next opens the queue.
  Disconnecting the display leaves playback running.

Visualizers and videos are not placed in the CarPlay audio interface. List
pagination replaces the current list, and search/download UI observes the
five-template stack limit. Pages reserve room for playback and page-navigation
controls even in cars that truncate lists to twelve rows.

On iOS the native output device is created on the first playback request;
`audio_session` owns audio-session activation before that request. CarPlay
startup also skips the media-session workaround that briefly advertises a
playing state solely to arm remote controls. Browsing must not activate the
audio session and interrupt the car's other audio source.

## Signing and distribution

iOS builds default to `REWAMP_WITH_CARPLAY=0`. They use
`Runner/Runner.entitlements`, which does not request CarPlay or Siri. Anyone can
build an ordinary version using their own normal signing setup.

Approved developers opt in by adding `REWAMP_WITH_CARPLAY = 1` to the gitignored
`app/ios/Flutter/Local.xcconfig`, or passing `REWAMP_WITH_CARPLAY=1` to
`xcodebuild`. This selects `Runner/CarPlay.entitlements` for the app target in
Debug, Profile and Release. The override also works with the existing Flutter
build commands when placed in the local config file. Desktop/Android settings
and embedded framework entitlements are unaffected.

The opt-in file requests `com.apple.developer.carplay-audio` and
`com.apple.developer.siri`. Enable both CarPlay Audio and Siri on the distributing
App ID and regenerate its profile. An existing CarPlay-only profile cannot sign
the Siri search update. The entitlement file is a request, not an Apple approval.

SiriKit uses scene-based in-app intent handling (`INIntentsSupported`) in
`AppDelegate`, sharing the normal Flutter engine. `INPlayMediaIntent` resolves
catalogue or playlist results and supports Siri's disambiguation;
`INSearchForMediaIntent` supplies results without starting playback. Requests use
Siri's structured search fields, with media-item/container metadata as a fallback.
References carry catalogue identity and search metadata rather than a process's
action token. After relaunch, a saved selection is resolved again and matched to
the same catalogue version before playback. Copies from different collections
have distinct spoken labels. A playlist request with no matching saved playlist
also searches the online catalogue.

Network, startup and malformed-response failures are reported as service
unavailability rather than a successful search with no matches. Recent artists,
playlist names and artists in search results supply bounded Siri vocabulary;
this does not require downloading the music or indexing the entire catalogue.
Vocabulary updates respect the CarPlay build opt-in.

Siri diagnostics stay in the app container at
`Library/Application Support/siri-diagnostics.jsonl`, with one `.previous` file.
Each file is bounded to 128 KiB and excluded from backup. The log records parsed
search fields, dispatch/readiness, timings, result counts and error codes, without
credentials or audio recordings. It can be retrieved from a development app's
container for a failed in-car test; it is not uploaded. Real Siri recognition and
routing still need a device test, even when catalogue and intent tests pass.

The developer distributing a CarPlay-enabled device build must:

1. Request Apple's CarPlay audio entitlement for their developer account and app.
2. Enable it on the App ID and obtain a matching development/distribution profile.
3. Sign with that team/profile. A fork needs its own bundle identifier and approval;
   a normal wildcard development profile does not grant CarPlay access.

The upstream bundle identifier and signing team are preserved in the project.
Do not commit personal team, profile or bundle identifier changes when preparing
an upstream pull request. Adding CarPlay source does not publish or submit the app.

For vehicle testing, use a Release build signed with a development profile that
includes the test iPhone, so the app can start without a connected Flutter debugger.
Apply a development bundle identifier to the Runner target only: a project-wide
`PRODUCT_BUNDLE_IDENTIFIER` override also changes embedded framework identifiers
and can prevent installation.

See Apple's [entitlement setup](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
and [CarPlay Developer Guide](https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf).
The guide dated 2026-10-13 adds the search template to audio apps on iOS 27;
using it on earlier systems is not supported by the audio entitlement.

## Build and automated validation

Enable the local opt-in above for CarPlay builds. Follow the native-library
prerequisites in [README.md](README.md), including
submodule patches and the iOS ANGLE/libopenmpt/vgmstream XCFrameworks, then:

```sh
cd app
flutter pub get
flutter analyze --no-pub lib/carplay.dart lib/app_shell.dart \
  lib/player_controller.dart lib/search_screen.dart lib/media_session.dart
flutter test --no-pub
flutter build ios --simulator --debug --no-codesign
```

`tool/check_carplay_ios.sh` can type-check the native host against the installed
iOS SDK before the decoder libraries are available. It substitutes only the
generated plugin registrant for that check; it does not link or run the app.

`python3 tool/check_ios_signing.py` checks Xcode's resolved entitlement selection
for ordinary and opted-in Debug, Profile and Release builds. It requires Xcode
and the generated Flutter iOS configuration, but does not build or sign the app.

Native Siri request, restart, service-error and diagnostic-log regression tests
are in `ios/RunnerTests/RunnerTests.swift`. From `app`, run them against an
available iPhone simulator with an ad-hoc-signed test host:

```sh
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -only-testing:RunnerTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

For a real-engine transport smoke test, build with the Xcode build-setting
override `FLUTTER_TARGET=tool/carplay_audio_smoke.dart`. It generates a quiet WAV
inside the app's cache, verifies that startup has no output device, then checks
first play, pause, resume and stop through the normal media handler. Look for
`[CarPlay audio smoke] PASSED` in the device log. Rebuild with
`FLUTTER_TARGET=lib/main.dart` afterward; the smoke entrypoint is not the app's
shipping entrypoint.

For the real catalogue/download/decoder path, build the disposable simulator
with `FLUTTER_TARGET=tool/carplay_download_smoke.dart`. It plays a catalogue
selection, then skips an uncached selection during its download. Look for
`[CarPlay download smoke] PASSED` in the simulator's unified log. This does not
exercise rendering on an actual CarPlay display. Restore `lib/main.dart` after
running the smoke entrypoint.

Focused tests are in `test/carplay_browser_test.dart`,
`test/carplay_download_test.dart`, `test/carplay_playback_test.dart` and
`test/carplay_session_test.dart`. They
exercise queue mutations, duplicate/subsong identity, restored playlists,
online pagination, redownloadable library rows, offline errors, the native/Dart
handshake, progress subscriptions, cancellation and phone-dialog isolation.
A local HTTP server holds a real download open to verify that playback waits
for all bytes and progress is visible before completion. Superseded downloads,
remote skipping, full-playlist actions and Siri search snapshots have dedicated
regression coverage.

## Manual acceptance checks

Xcode 27's Device Hub does not support CarPlay with virtual iPhones. Its CarPlay
simulator connects to a physical iPhone, which still needs a signed build with
the approved entitlement. Apple confirms this in
[developer forum thread 834440](https://developer.apple.com/forums/thread/834440).
An earlier Xcode simulator with a CarPlay external display can exercise the
older browsing/playback UI; iOS 27 search still needs a supported test setup.
Use a signed device in a CarPlay vehicle for final acceptance.

1. Cold-launch from CarPlay with no phone scene; browse and play, then open the
   phone and confirm that it shows the same track and queue.
2. Open the phone first, connect/disconnect/reconnect CarPlay, and verify that
   there is still one playback session and playback survives disconnection.
3. Test play/pause, next/previous, steering-wheel controls, metadata/artwork,
   Up Next and selecting subsongs. Reorder/remove a queue entry on the phone
   immediately before selecting its displayed car row.
4. Browse a collection past the first page, play a new download, observe
   progress, cancel a slow transfer, and retry after a network failure. Test a
   simple module, a subsong container, and an archive album with auxiliary files.
5. Restore a playlist on a device without its downloads and play several
   consecutive catalogue entries. Verify offline cached playback and missing
   local-only files.
6. On iOS 27+, search locally, globally and within a collection, type quickly,
   clear the query, and test with the car's keyboard disabled. On iOS 15–26
   verify that keyboard search is not offered, and use the Browse Siri assistant
   to find and play a catalogue track and a named playlist. Verify Siri's
   disambiguation and behaviour while the phone is locked.
7. Start Play all and Shuffle from a playlist page other than the first. Check
   the full queue, explicit shuffle mode and duplicate/subsong entries. Toggle
   shuffle on/off from Now Playing without restarting the current track; verify
   the selected appearance after phone-side changes and CarPlay reconnect.
8. During an uncached first track, skip using the on-screen progress control
   and a steering-wheel button. The skipped track must not start later, and no
   error should appear for intentional cancellation.
9. Test while the phone is locked, during calls/audio interruptions, at the
   maximum navigation depth, and while another car audio source is playing.
   Opening Rewamp for browsing alone must not interrupt that source.

Automated tests and a headless engine smoke test do not replace these complete
CarPlay and vehicle acceptance checks.

## Validation

The implementation has been checked with the full Flutter suite (934 tests),
13 native Siri XCTest cases, changed-Dart analysis and the native iOS SDK
type-check. Seven explicit live catalogue lookups also passed, including
“The Bullet” by Randall (and “Randal”), “Acidland Metropolis” by Booster and
“Durban Poison” by Randall.

Simulator smoke tests exercised the real audio engine, catalogue downloads,
skipping an unfinished download and upstream autoplay maintenance. Both ordinary
and opted-in signing configurations were checked, and a signed Release build
was installed and tested in a CarPlay vehicle. The tester reported that the
latest Siri search update worked well in the car.

These results are a validation snapshot, not a claim that every manual check
above has been completed across all supported iOS versions and vehicles.
