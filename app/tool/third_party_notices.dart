// Builds THIRD-PARTY-NOTICES.md from lib/engines.dart.
//
// It IMPORTS the registry rather than parsing it: engines.dart is the single
// source for the About screen, and a notices file built by a regex would drift
// from it the first time someone adds a row in a shape the regex did not expect
// — silently, which is the failure mode that matters for a licence file.
//
// ⚠️ Run through `flutter test`, not `dart run`: engines.dart pulls in
// rewamp_db.dart and with it the FFI plugin, which the plain Dart VM refuses to
// compile ("type 'InvalidType' is not a subtype of type 'FunctionType'"). The
// flutter test host loads it fine — the same reason the other tests can import
// rewamp_db.dart at all.
//
//   cd app && REWAMP_WRITE_NOTICES=1 flutter test test/third_party_notices_test.dart
//
// Without the variable that same test only CHECKS the file on disk, so a row
// added to engines.dart without regenerating turns the suite red.
import 'package:rewamp/engines.dart';

/// The one-line role, in French, taken from the row itself — the notices file
/// is not localized (a licence notice is a legal artifact, and the ARB strings
/// only exist for the languages the UI ships).
String _row(String name, String license, String? author, String? url,
    [String? description]) {
  final b = StringBuffer('| ');
  b.write(url == null ? _esc(name) : '[${_esc(name)}]($url)');
  b.write(' | ');
  b.write(_esc(license));
  b.write(' | ');
  b.write(author == null ? '—' : _esc(author));
  if (description != null) {
    b.write(' | ');
    b.write(_esc(description));
  }
  b.write(' |');
  return b.toString();
}

/// A pipe inside a cell breaks the table; a few author fields carry one.
String _esc(String s) => s.replaceAll('|', r'\|');

String buildThirdPartyNotices() {
  final out = StringBuffer();

  out.writeln('# Third-party notices');
  out.writeln();
  out.writeln('Rewamp bundles the decoders, visualizers and support libraries');
  out.writeln('listed below. Each keeps its own licence and its own authors;');
  out.writeln('this file exists so the binary states what it redistributes.');
  out.writeln();
  out.writeln('**Generated — do not edit by hand.** The source of truth is');
  out.writeln('`app/lib/engines.dart`, the same list the app shows under');
  out.writeln('Settings → About. Regenerate with:');
  out.writeln();
  out.writeln('```bash');
  out.writeln('cd app && REWAMP_WRITE_NOTICES=1 \\');
  out.writeln('  flutter test test/third_party_notices_test.dart');
  out.writeln('```');
  out.writeln();
  out.writeln('(a `flutter test`, not a `dart run`: engines.dart pulls in the');
  out.writeln('FFI plugin, which the plain Dart VM refuses to compile. The same');
  out.writeln('test CHECKS the file without the variable, so a row added');
  out.writeln('without regenerating turns the suite red.)');
  out.writeln();
  out.writeln('See [LICENSING.md](LICENSING.md) for how these licences combine,');
  out.writeln('and for the two that constrain what may be redistributed.');
  out.writeln();

  out.writeln('## Playback engines (${kEngines.length})');
  out.writeln();
  out.writeln('$kTotalFormatCount file extensions across all of them.');
  out.writeln();
  out.writeln('| Engine | Licence | Authors | Role |');
  out.writeln('| --- | --- | --- | --- |');
  final engines = [...kEngines]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final e in engines) {
    out.writeln(_row(e.name, e.license, e.author, e.url, e.description));
  }
  out.writeln();

  out.writeln('## Bundled components (${kComponents.length})');
  out.writeln();
  out.writeln('Everything the binary redistributes that is not a decoder:');
  out.writeln('archive handling, the visualizer, fonts, shaders, data sets.');
  out.writeln();
  out.writeln('| Component | Licence | Authors |');
  out.writeln('| --- | --- | --- |');
  final comps = [...kComponents]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final c in comps) {
    out.writeln(_row(c.name, c.license, c.author, c.url));
  }
  out.writeln();

  // UnRAR's licence REQUIRES this paragraph to travel with any distribution.
  // It is not a courtesy line: reproducing it is the condition of use.
  out.writeln('## UnRAR — required notice');
  out.writeln();
  out.writeln('The UnRAR licence requires the following paragraph to be');
  out.writeln('reproduced in the licence or documentation of any package that');
  out.writeln('includes it. The full text is in');
  out.writeln('`packages/rewamp_audio/third_party/unrar/license.txt`.');
  out.writeln();
  out.writeln('> UnRAR source code may be used in any software to handle RAR');
  out.writeln('> archives without limitations free of charge, but cannot be');
  out.writeln('> used to develop RAR (WinRAR) compatible archiver and to');
  out.writeln('> re-create RAR compression algorithm, which is proprietary.');
  out.writeln('> Distribution of modified UnRAR source code in separate form');
  out.writeln('> or as a part of other software is permitted, provided that');
  out.writeln('> full text of this paragraph, starting from "UnRAR source');
  out.writeln('> code" words, is included in license, or in documentation if');
  out.writeln('> license is not available, and in source code comments of');
  out.writeln('> resulting package.');
  out.writeln();

  out.writeln('## Attribution asked for by name');
  out.writeln();
  out.writeln('Some licences ask for a visible credit rather than only a file.');
  out.writeln('These appear in the app itself, under Settings → About:');
  out.writeln();
  out.writeln('- **SunVox** — © 2008–2026 Alexander Zolotov · WarmPlace.ru');
  out.writeln('  (the vendored sources are MIT; the credit is asked for by the');
  out.writeln('  project and carried on its engine row).');
  out.writeln('- **UADE song database** — CC BY-NC-SA, per-subsong lengths.');
  out.writeln('- **Milkwave** — BSD-3, preset-transition patterns.');
  out.writeln('- **Shadertoy spectrum shader** — CC BY 3.0, Jan Mróz.');

  return out.toString();
}
