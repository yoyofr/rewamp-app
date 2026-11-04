// Ligne de commande du bureau: UNE table d'options, UN analyseur.
//
// Trois plateformes, trois transports (macOS: URL `rewamp://cli`; Linux:
// GApplication sur D-Bus; Windows: WM_COPYDATA), mais tous livrent à Dart la
// même chose — les arguments BRUTS et le dossier courant de l'invocation — et
// c'est ICI qu'ils prennent un sens. Une règle écrite deux fois diverge: le
// natif n'interprète rien, sauf ce qu'il DOIT décider avant que Dart existe
// (`--help`, `--version`, « une commande de pilotage sans instance lancée »),
// et il le lit dans `assets/cli/cli_manifest.json`, GÉNÉRÉ depuis
// [kCliOptions] (test/cli_manifest_sync_test.dart rougit à la dérive).
//
// Pur et sans Flutter: testable sous `p.posix` comme sous `p.windows`.
import 'dart:convert';

import 'package:path/path.dart' as p;

/// Où mettre les fichiers nommés.
enum CliPlacement {
  /// Pas d'option: la feuille de choix habituelle, comme un dépôt.
  ask,
  /// `--play`: remplace la file, sans demander.
  now,
  /// `--next`: juste après le morceau en cours.
  next,
  /// `--enqueue`: à la fin de la file.
  end,
}

/// Pilotage d'une instance DÉJÀ lancée.
enum CliRemote { playPause, nextTrack, prevTrack, stop }

class CliOption {
  const CliOption(this.name, this.help, {this.value, this.remote = false});

  /// Sans les deux tirets.
  final String name;
  final String help;

  /// Nom de la valeur attendue (`N`), null = drapeau.
  final String? value;

  /// N'a de sens que si l'app tourne déjà: sans instance, le natif le dit et
  /// sort en erreur au lieu de lancer l'app pour rien.
  final bool remote;
}

/// La table. L'aide est en ANGLAIS: c'est la convention d'une ligne de
/// commande, et le natif l'imprime avant que Flutter (et l10n) n'existe.
const kCliOptions = <CliOption>[
  CliOption('play', 'Replace the queue with FILES and start playing.'),
  CliOption('next', 'Insert FILES right after the current track.'),
  CliOption('enqueue', 'Append FILES to the end of the queue.'),
  CliOption('shuffle', 'Play FILES in random order.'),
  CliOption('subsong', 'Start a multi-track FILE at its N-th track (1-based).',
      value: 'N'),
  CliOption('play-pause', 'Toggle play / pause.', remote: true),
  CliOption('next-track', 'Skip to the next track.', remote: true),
  CliOption('prev-track', 'Go back to the previous track.', remote: true),
  CliOption('stop', 'Stop playback.', remote: true),
  CliOption('mini', 'Switch to the mini player (with --viz: its visualizer '
      'mode).'),
  CliOption('window', 'Use the normal window (leaves the mini player; '
      'overrides a start in the mini player).'),
  CliOption('viz', 'Open the player on the visualizer.'),
  CliOption('fullscreen', 'Open the player on the visualizer, full screen.'),
  CliOption('search', 'Open Search with TEXT.', value: 'TEXT'),
  CliOption('help', 'Show this help and exit.'),
  CliOption('version', 'Show the version and exit.'),
];

CliOption? _optionNamed(String name) {
  for (final o in kCliOptions) {
    if (o.name == name) return o;
  }
  return null;
}

class CliCommand {
  CliCommand({
    this.files = const [],
    this.placement = CliPlacement.ask,
    this.shuffle = false,
    this.subsong,
    this.remote,
    this.mini = false,
    this.window = false,
    this.viz = false,
    this.fullscreen = false,
    this.search,
    this.help = false,
    this.version = false,
    this.unknown = const [],
    this.errors = const [],
  });

  /// ABSOLUS, dans l'ordre de la ligne de commande. Leur existence n'est pas
  /// vérifiée ici (l'analyseur est pur): l'appelant filtre.
  final List<String> files;
  final CliPlacement placement;
  final bool shuffle;

  /// 1-based, tel que tapé.
  final int? subsong;
  final CliRemote? remote;

  /// Affichage. `--viz`, `--fullscreen` et `--search` veulent la fenêtre
  /// principale: sans `--mini`, ils font SORTIR du mini lecteur.
  final bool mini;

  /// La fenêtre NORMALE: sort du mini lecteur, et au démarrage l'emporte sur
  /// le réglage « Au démarrage: mini lecteur ».
  final bool window;
  final bool viz;
  final bool fullscreen;

  /// Texte à chercher, déjà rogné; null = pas de recherche.
  final String? search;
  final bool help;
  final bool version;

  /// Options `--x` que nous ne connaissons pas (celles du moteur Flutter par
  /// exemple): ignorées, jamais une erreur.
  final List<String> unknown;

  /// Valeur manquante ou invalide — l'option est ignorée, le reste s'applique.
  final List<String> errors;

  bool get hasDisplay =>
      mini || window || viz || fullscreen || search != null;

  bool get isEmpty =>
      files.isEmpty && remote == null && !hasDisplay && !help && !version;
}

/// Analyse [args] (sans `argv[0]`) tapés dans [cwd].
///
/// Règles:
/// - `--nom` ou `--nom=valeur`; une option à valeur prend aussi l'argument
///   SUIVANT (`--subsong 3`).
/// - Un tiret SEUL (`-NSDocumentRevisionsDebugMode YES`, `-AppleLanguages
///   (fr)`, que Xcode et macOS ajoutent) n'est jamais à nous: un nom qui
///   commence par une MAJUSCULE est un réglage Cocoa et emporte sa valeur,
///   tout autre (`-psn_0_123`) est écarté seul.
/// - `--` termine les options: ce qui suit est un fichier même s'il commence
///   par un tiret.
/// - Un `file://` est converti en chemin; un relatif est résolu contre [cwd].
/// - Pour les placements, le DERNIER l'emporte; pour le pilotage aussi.
CliCommand parseCommandLine(List<String> args,
    {required String cwd, p.Context? ctx}) {
  final c = ctx ?? p.context;
  final files = <String>[];
  final unknown = <String>[];
  final errors = <String>[];
  var placement = CliPlacement.ask;
  var shuffle = false;
  int? subsong;
  CliRemote? remote;
  var mini = false;
  var window = false;
  var viz = false;
  var fullscreen = false;
  String? search;
  var help = false;
  var version = false;
  var onlyFiles = false;

  String toAbsolute(String a) {
    if (a.startsWith('file://')) {
      try {
        return Uri.parse(a).toFilePath(windows: c.style == p.Style.windows);
      } catch (_) {/* pas une URI valide: traité comme un chemin */}
    }
    return c.normalize(c.isAbsolute(a) ? a : c.join(cwd, a));
  }

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.isEmpty) continue;
    if (onlyFiles) {
      files.add(toAbsolute(a));
      continue;
    }
    if (a == '--') {
      onlyFiles = true;
      continue;
    }
    if (a.startsWith('--')) {
      final eq = a.indexOf('=');
      final name = a.substring(2, eq < 0 ? a.length : eq);
      final opt = _optionNamed(name);
      if (opt == null) {
        unknown.add(a);
        continue;
      }
      String? value;
      if (opt.value != null) {
        if (eq >= 0) {
          value = a.substring(eq + 1);
        } else if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          value = args[++i];
        }
        if (value == null || value.isEmpty) {
          errors.add('--$name needs a value (${opt.value})');
          continue;
        }
      } else if (eq >= 0) {
        errors.add('--$name takes no value');
        continue;
      }
      switch (name) {
        case 'play':
          placement = CliPlacement.now;
        case 'next':
          placement = CliPlacement.next;
        case 'enqueue':
          placement = CliPlacement.end;
        case 'shuffle':
          shuffle = true;
        case 'subsong':
          final n = int.tryParse(value!);
          if (n == null || n < 1) {
            errors.add('--subsong expects a number from 1, got "$value"');
          } else {
            subsong = n;
          }
        case 'play-pause':
          remote = CliRemote.playPause;
        case 'next-track':
          remote = CliRemote.nextTrack;
        case 'prev-track':
          remote = CliRemote.prevTrack;
        case 'stop':
          remote = CliRemote.stop;
        case 'mini':
          mini = true;
        case 'window':
          window = true;
        case 'viz':
          viz = true;
        case 'fullscreen':
          fullscreen = true;
        case 'search':
          final q = value!.trim();
          if (q.isEmpty) {
            errors.add('--search needs some text');
          } else {
            search = q;
          }
        case 'help':
          help = true;
        case 'version':
          version = true;
      }
      continue;
    }
    if (a.startsWith('-') && a.length > 1) {
      // Réglage Cocoa (`-NSFoo YES`): il emporte sa valeur.
      final first = a.codeUnitAt(1);
      final cocoa = first >= 0x41 && first <= 0x5A;
      if (cocoa && i + 1 < args.length && !args[i + 1].startsWith('-')) i++;
      continue;
    }
    files.add(toAbsolute(a));
  }

  return CliCommand(
    files: files,
    placement: placement,
    shuffle: shuffle,
    subsong: subsong,
    remote: remote,
    mini: mini,
    window: window,
    viz: viz,
    fullscreen: fullscreen,
    search: search,
    help: help,
    version: version,
    unknown: unknown,
    errors: errors,
  );
}

/// L'aide imprimée par `--help`, sans la ligne de version (le natif la lit
/// dans le bundle).
String cliHelpText() {
  final b = StringBuffer()
    ..writeln('Usage: rewamp [OPTIONS] [FILES...]')
    ..writeln()
    ..writeln('Without options, FILES open the usual "play now / next / at '
        'the end" choice.')
    ..writeln('When Rewamp is already running, the command goes to it;')
    ..writeln('otherwise Rewamp starts with it (e.g. rewamp --mini --play '
        'song.mod).')
    ..writeln()
    ..writeln('Options:');
  final cols = [
    for (final o in kCliOptions)
      '  --${o.name}${o.value == null ? '' : ' ${o.value}'}',
  ];
  final width = cols.fold<int>(0, (m, s) => s.length > m ? s.length : m) + 2;
  for (var i = 0; i < kCliOptions.length; i++) {
    b.writeln('${cols[i].padRight(width)}${kCliOptions[i].help}');
  }
  return b.toString();
}

/// Ce que le natif lit avant que Dart n'existe. Clés STABLES: le Swift, le
/// C++ GTK et le Win32 les lisent par nom.
String cliManifestJson() {
  const enc = JsonEncoder.withIndent('  ');
  return '${enc.convert({
        'comment': 'GENERATED from app/lib/cli_options.dart — do not edit. '
            'Regenerate: cd app && REWAMP_WRITE_CLI_MANIFEST=1 flutter test '
            'test/cli_manifest_sync_test.dart',
        'help': cliHelpText(),
        'options': [
          for (final o in kCliOptions)
            {
              'name': o.name,
              'value': o.value != null,
              'remote': o.remote,
            },
        ],
      })}\n';
}
