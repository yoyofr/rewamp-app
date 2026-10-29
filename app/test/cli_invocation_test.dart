// Ce que l'app fait d'une ligne de commande reçue (local_open.dart): le
// dossier courant de l'INVOCATION, et une URL sans jeton qui ne fait rien
// ouvrir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/cli_options.dart';
import 'package:rewamp/local_open.dart';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('cli_inv');
    File(p.join(dir.path, 'a.mod')).writeAsStringSync('x');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('Linux/Windows: le --cwd= de tête est le dossier de l\'invocation', () {
    final inv = CliInvocation.fromNative(['--cwd=${dir.path}', '--enqueue', 'a.mod'])!;
    expect(inv.cwd, dir.path);
    expect(inv.args, ['--enqueue', 'a.mod']);
    final cmd = cliCommandFor(inv)!;
    expect(cmd.files, [p.join(dir.path, 'a.mod')]);
    expect(cmd.placement, CliPlacement.end);
  });

  test('macOS: table {args, cwd, trusted}', () {
    final inv = CliInvocation.fromNative(
        {'args': ['a.mod'], 'cwd': dir.path, 'trusted': true})!;
    expect(inv.trusted, isTrue);
    expect(cliCommandFor(inv)!.files, hasLength(1));
  });

  test('sans jeton: le pilotage passe, les chemins non', () {
    final inv = CliInvocation.fromNative(
        {'args': ['a.mod', '--play-pause'], 'cwd': dir.path, 'trusted': false})!;
    final cmd = cliCommandFor(inv)!;
    expect(cmd.files, isEmpty);
    expect(cmd.remote, CliRemote.playPause);
    expect(
        cliCommandFor(CliInvocation.fromNative(
            {'args': ['a.mod'], 'cwd': dir.path, 'trusted': false})!),
        isNull);
  });

  test('un fichier absent est écarté, une commande vide ne fait rien', () {
    expect(
        cliCommandFor(CliInvocation(['nope.mod'], cwd: dir.path)), isNull);
    expect(cliCommandFor(CliInvocation(['--enable-impeller'], cwd: dir.path)),
        isNull);
  });

  test('l\'affichage passe sans jeton et survit au filtrage', () {
    final cmd = cliCommandFor(CliInvocation.fromNative({
      'args': ['--mini', '--viz', '--search', 'hubbard', 'a.mod'],
      'cwd': dir.path,
      'trusted': false,
    })!)!;
    expect(cmd.files, isEmpty);
    expect(cmd.mini, isTrue);
    expect(cmd.viz, isTrue);
    expect(cmd.search, 'hubbard');
  });

  test('démarrage à froid: une option d\'affichage saute l\'intro, la '
      'commande reste en attente pour le shell', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    seedOpenedPathsFromArgs(['--cwd=${dir.path}', '--play', 'a.mod']);
    expect((await planLaunch(prefersMini: false)).skipIntro, isFalse);
    seedOpenedPathsFromArgs(['--cwd=${dir.path}', '--mini', '--play', 'a.mod']);
    final plan = await planLaunch(prefersMini: false);
    expect(plan.skipIntro, isTrue);
    expect(plan.miniFromSetting, isFalse); // la ligne de commande s'en charge
    // Le shell monté tire le tout, dans l'ordre.
    final ran = <CliCommand>[];
    globalRunCliCommand = (c) async => ran.add(c);
    await drainCliCommands();
    globalRunCliCommand = null;
    expect(ran.map((c) => c.mini), [false, true]);
    expect(ran.last.placement, CliPlacement.now);
    expect((await planLaunch(prefersMini: false)).skipIntro, isFalse);
  });

  test('démarrage en mini par le RÉGLAGE, sauf --window ou --mini', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    var plan = await planLaunch(prefersMini: true);
    expect(plan.miniFromSetting, isTrue);
    expect(plan.skipIntro, isTrue);
    seedOpenedPathsFromArgs(['--cwd=${dir.path}', '--window']);
    plan = await planLaunch(prefersMini: true);
    expect(plan.miniFromSetting, isFalse);
    seedOpenedPathsFromArgs(['--cwd=${dir.path}', '--mini']);
    plan = await planLaunch(prefersMini: true);
    expect(plan.miniFromSetting, isFalse);
    globalRunCliCommand = (c) async {};
    await drainCliCommands();
    globalRunCliCommand = null;
  });
}

