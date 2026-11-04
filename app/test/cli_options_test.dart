// Analyseur de ligne de commande (cli_options.dart): pur, sous les deux
// styles de chemins.
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rewamp/cli_options.dart';

void main() {
  CliCommand parse(List<String> a, {String cwd = '/home/u/mods'}) =>
      parseCommandLine(a, cwd: cwd, ctx: p.posix);

  test('sans option: fichiers absolus, la feuille de choix décide', () {
    final c = parse(['a.mod', '../sid/b.sid', '/abs/c.vgz']);
    expect(c.files, ['/home/u/mods/a.mod', '/home/u/sid/b.sid', '/abs/c.vgz']);
    expect(c.placement, CliPlacement.ask);
    expect(c.remote, isNull);
  });

  test('placements: le dernier l\'emporte', () {
    expect(parse(['--enqueue', 'a.mod']).placement, CliPlacement.end);
    expect(parse(['--next', 'a.mod']).placement, CliPlacement.next);
    expect(parse(['--next', '--play', 'a.mod']).placement, CliPlacement.now);
  });

  test('une option à valeur prend la suivante ou =', () {
    final a = parse(['--subsong', '3', 'x.nsf']);
    expect(a.subsong, 3);
    expect(a.files, ['/home/u/mods/x.nsf']); // « 3 » n'est pas un fichier
    expect(parse(['--subsong=4', 'x.nsf']).subsong, 4);
    final bad = parse(['--subsong', 'zéro', 'x.nsf']);
    expect(bad.subsong, isNull);
    expect(bad.errors, isNotEmpty);
    expect(parse(['--subsong']).errors, isNotEmpty);
    expect(parse(['--subsong=0']).subsong, isNull);
  });

  test('pilotage', () {
    expect(parse(['--play-pause']).remote, CliRemote.playPause);
    expect(parse(['--next-track']).remote, CliRemote.nextTrack);
    expect(parse(['--prev-track']).remote, CliRemote.prevTrack);
    expect(parse(['--stop']).remote, CliRemote.stop);
    expect(parse(['--play-pause']).files, isEmpty);
  });

  test('options inconnues et réglages Cocoa ignorés, sans manger un fichier',
      () {
    final c = parse([
      '-NSDocumentRevisionsDebugMode', 'YES',
      '-psn_0_12345',
      '--enable-impeller',
      'a.mod',
    ]);
    expect(c.files, ['/home/u/mods/a.mod']);
    expect(c.unknown, ['--enable-impeller']);
  });

  test('`--` termine les options', () {
    expect(parse(['--', '--weird.mod']).files, ['/home/u/mods/--weird.mod']);
  });

  test('file:// et chemins Windows', () {
    expect(parse(['file:///abs/a%20b.mod']).files, ['/abs/a b.mod']);
    final w = parseCommandLine([r'mods\a.mod', r'D:\x\b.sid'],
        cwd: r'C:\Users\u', ctx: p.windows);
    expect(w.files, [r'C:\Users\u\mods\a.mod', r'D:\x\b.sid']);
  });

  test('help / version', () {
    expect(parse(['--help']).help, isTrue);
    expect(parse(['--version']).version, isTrue);
    expect(cliHelpText(), contains('--subsong N'));
    for (final o in kCliOptions) {
      expect(cliHelpText(), contains('--${o.name}'));
    }
  });

  test('affichage', () {
    final c = parse(['--mini', '--viz', 'a.mod']);
    expect(c.mini, isTrue);
    expect(c.viz, isTrue);
    expect(c.files, ['/home/u/mods/a.mod']);
    expect(parse(['--fullscreen']).fullscreen, isTrue);
    expect(parse(['--fullscreen']).isEmpty, isFalse);
    final s = parse(['--search', '  rob hubbard ', 'x.sid']);
    expect(s.search, 'rob hubbard');
    expect(s.files, ['/home/u/mods/x.sid']); // le texte n'est pas un fichier
    expect(parse(['--search=']).search, isNull);
    expect(parse(['--search=   ']).errors, isNotEmpty);
  });

  test('--window', () {
    final c = parse(['--window']);
    expect(c.window, isTrue);
    expect(c.hasDisplay, isTrue);
  });
}
