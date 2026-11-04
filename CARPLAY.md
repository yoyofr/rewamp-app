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

`Runner/Runner.entitlements` requests `com.apple.developer.carplay-audio` and
`com.apple.developer.siri` in all build configurations. Enable both CarPlay Audio
and Siri on the distributing App ID and regenerate its profile. An existing
CarPlay-only profile cannot sign the Siri search update. This file is a request,
not an Apple approval.

SiriKit uses scene-based in-app intent handling (`INIntentsSupported`) in
`AppDelegate`, sharing the normal Flutter engine. `INPlayMediaIntent` resolves
catalogue or playlist results and supports Siri's disambiguation;
`INSearchForMediaIntent` supplies results without starting playback. Only
process-specific resolved identifiers are accepted, preventing an old Siri
selection from being reused for a different item after relaunch.

The developer distributing a device build must:

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

Follow the native-library prerequisites in [README.md](README.md), including
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

## Validation on 2026-10-29

- Dart analysis: no findings in the changed app code and smoke entrypoint.
- Full Flutter suite: 831 tests passed, including 22 CarPlay regression tests.
- Native host: SDK type-check and complete arm64 iOS simulator build passed
  with Xcode 27.1.
- Real-engine smoke test on iOS 27 Simulator: output absent at startup, created
  on first play; play, pause, resume and stop passed.
- Headless Flutter startup: the widget tree builds without a phone window.
- Signed arm64 Release device build: passed. The CarPlay audio entitlement was
  verified in both the development profile and app signature. Installation and
  standalone launch passed on the registered test iPhone running iOS 26.7.1.
- CarPlay screen/vehicle acceptance: pending a suitable simulator setup or an
  in-car test. Device Hub's CarPlay connection timed out with the USB-connected
  test iPhone; a valid entitlement and successful installation do not replace
  CarPlay screen and vehicle acceptance checks.

## Vehicle feedback on 2026-10-30

The tester confirmed that the original CarPlay build works in the vehicle.
Reported follow-ups were first-time download playback errors, skipping during
those downloads, catalogue search, and playlist Play/Shuffle actions. The update
addresses those paths; its new vehicle behaviour and Siri interaction still
require in-car acceptance testing.

- Full Flutter suite: 844 tests passed (35 focused CarPlay tests).
- Analyzer: no findings in changed Dart source, tests and download smoke tool.
- Native host: SDK type-check and full arm64 simulator build passed. A complete
  Release iPhone build also compiled successfully with signing disabled.
- Real catalogue/download/decoder smoke: first uncached selection downloaded
  and started playback in the iOS 27 simulator. A second uncached request was
  skipped during its download; the next track downloaded and played, while the
  skipped selection returned cancellation without starting later.
- Updated physical-device signing initially failed: Xcode reported no available
  account and the cached development profile did not contain Siri. Signing was
  subsequently resolved by authenticating the test developer account and
  refreshing the profile, as recorded below.

### Now Playing shuffle follow-up

Added the system `CPNowPlayingShuffleButton` to the player view, wired through
`PlayerController.toggleShuffle` to the existing queue reorder/persistence path.
The car's selected appearance uses `MPChangeShuffleModeCommand.currentShuffleType`,
as required for system-provided shuffle buttons. The media handler also reports
shuffle mode and handles absolute system shuffle requests idempotently.

Regression tests cover on/off taps, restored state, phone-side updates,
reconnect and repeated system requests. The full Flutter suite passed all 847
tests; changed Dart source/tests have no analyzer findings and the native SDK
type-check passed. The new button's actual car-screen rendering remains a device
acceptance check.

### Updated signed phone installation on 2026-10-30

The Release build from source commit `921b7ae` was signed, installed as an update
on the registered test iPhone running iOS 26.7.1, and launched normally without
a debugger. The new process remained running after launch.

Both the embedded provisioning profile and app signature were verified to
contain CarPlay Audio and Siri, with the test device included in the profile.
Deep strict signature verification passed, and all 16 nested bundle identifiers
were distinct. The build used the normal `lib/main.dart` entrypoint; upstream
bundle/team settings and the tracked dependency lockfile were restored after
building. Downloads, skipping, search, playlist actions and the Now Playing
shuffle toggle are now available for a new in-car acceptance test.

## Siri title/artist search correction on 2026-11-04

A vehicle request for “The Bullet by Randall” exposed a query-composition bug:
Siri's media name, artist and album were flattened into one text query. The
catalogue returns no rows for “The Bullet Randall”, although a separate title
query and artist filter find the MOD in Modland and AMP. A one-letter “Randal”
artist transcription also misses the catalogue's strict artist filter.

The Siri bridge now preserves those fields. A bounded artist lookup corrects
small spelling differences to canonical artist IDs, rejecting unrelated names
returned by cross-entity fuzzy search. A complete “title by artist” phrase left
in the media-name field is retried in structured form only after its literal
search misses. Exact track titles take priority over album matches in the five
Siri choices; conservative fuzzy-title fallback keeps artist/album constraints.

Offline regression coverage includes both artist spellings, whole phrases,
artist/album field preservation, real titles containing “by”, and rejection of
unrelated fuzzy matches. All 862 Flutter tests passed. The explicit live check
`flutter test --no-pub tool/carplay_voice_search_smoke.dart` also passed three
lookups against the real catalogue, finding the Randall MOD for “Randall”,
“Randal”, and “The Bullet by Randal”. The exact transcript from the vehicle
request remains unknown, so Siri recognition still needs a new in-car test.
