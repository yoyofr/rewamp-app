// The hidden intro picker's probe: a finger HELD while the intro plays. The
// plumbing is exercised here independently of whether the OS delivers the
// touch — on a device both failures look identical (nothing happens), and it
// took a narrating build to find out the OS delivered nothing at all when the
// finger was already down before the app's window existed.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/splash_intro.dart';

ui.PointerDataPacket _touch(ui.PointerChange change, double x, double y,
        {ui.PointerDeviceKind kind = ui.PointerDeviceKind.touch}) =>
    ui.PointerDataPacket(data: <ui.PointerData>[
      ui.PointerData(change: change, kind: kind, physicalX: x, physicalY: y),
    ]);

void _send(ui.PointerChange change, double x, double y,
        {ui.PointerDeviceKind kind = ui.PointerDeviceKind.touch}) =>
    ui.PlatformDispatcher.instance
        .onPointerDataPacket!(_touch(change, x, y, kind: kind));

/// Longer than the hold, so a completed hold has fired by the time we look.
Future<void> _pastHold() =>
    Future<void>.delayed(kSplashHoldTime + const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The app installs this on the first line of main(); here it is installed
  // once for the whole file and re-armed per test.
  setUpAll(installLaunchTouchProbe);
  setUp(resetLaunchTouchProbeForTest);
  tearDown(stopLaunchTouchProbe);

  test('un doigt maintenu AVANT que le consommateur existe est mis en tampon',
      () async {
    // The whole point of a probe rather than a Listener: during boot there is
    // no widget tree at all, and main() is slow (assets, DB, shaders).
    _send(ui.PointerChange.down, 300, 600);
    await _pastHold();

    Offset? got;
    listenLaunchTouch((p) => got = p);
    expect(got, isNull, reason: 'la remise doit être asynchrone');
    await Future<void>.delayed(Duration.zero);
    // PHYSICAL pixels, untouched: the consumer measures the grid against the
    // same view's physicalSize, so no devicePixelRatio has to be known this
    // early — a wrong one lands the finger in an empty cell, silently.
    expect(got, const Offset(300, 600),
        reason: 'le maintien du démarrage a été perdu');
  });

  test('un doigt maintenu APRÈS le consommateur arrive aussi', () async {
    Offset? got;
    listenLaunchTouch((p) => got = p);
    _send(ui.PointerChange.down, 120, 90);
    await _pastHold();
    expect(got, const Offset(120, 90));
  });

  test('un appui BREF ne force rien — c\'est un tap impatient', () async {
    Offset? got;
    listenLaunchTouch((p) => got = p);
    _send(ui.PointerChange.down, 120, 90);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    _send(ui.PointerChange.up, 120, 90);
    await _pastHold();
    expect(got, isNull);
  });

  test('la position retenue est celle du DÉBUT, pas celle de la dérive',
      () async {
    Offset? got;
    listenLaunchTouch((p) => got = p);
    _send(ui.PointerChange.down, 100, 100);
    _send(ui.PointerChange.move, 900, 900);
    await _pastHold();
    expect(got, const Offset(100, 100), reason: 'la case visée est la première');
  });

  test('un survol à la souris ne force rien', () async {
    Offset? got;
    listenLaunchTouch((p) => got = p);
    for (final c in [ui.PointerChange.add, ui.PointerChange.hover]) {
      _send(c, 10, 20, kind: ui.PointerDeviceKind.mouse);
    }
    await _pastHold();
    expect(got, isNull, reason: 'un curseur qui passe ne choisit pas un effet');
  });

  test("le handler précédent est TOUJOURS rappelé (sinon l'app perd l'entrée)",
      () async {
    var forwarded = 0;
    final probe = ui.PlatformDispatcher.instance.onPointerDataPacket!;
    ui.PlatformDispatcher.instance.onPointerDataPacket = (p) {
      forwarded++;
      probe(p);
    };
    listenLaunchTouch((_) {});
    _send(ui.PointerChange.down, 1, 1);
    await _pastHold();
    expect(forwarded, 1);
    ui.PlatformDispatcher.instance.onPointerDataPacket = probe;
  });

  test('une fois consommé, la sonde se tait', () async {
    var hits = 0;
    listenLaunchTouch((_) => hits++);
    _send(ui.PointerChange.down, 5, 5);
    await _pastHold();
    _send(ui.PointerChange.up, 5, 5);
    _send(ui.PointerChange.down, 50, 50);
    await _pastHold();
    expect(hits, 1);
  });
}
