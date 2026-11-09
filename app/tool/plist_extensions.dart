// Regenerates the extension lists of the two Apple Info.plist files from the
// engine registry.
//
// macOS and iOS learn what Rewamp opens from Info.plist, in two places:
//   - the exported UTI `com.rewamp.app.trackermodule`, whose
//     `public.filename-extension` tag lists every extension (both platforms);
//   - the "Chiptune (by extension)" document type, whose
//     `CFBundleTypeExtensions` binds the same extensions directly (macOS only —
//     an extension has ONE UTI owner, and when another app exports `sndh` or
//     `sc68` our UTI binds nothing for it; see macos-file-open-uti).
//
// Those lists were written once by hand and never followed `engines.dart`:
// on 2026-10-18 the registry knew 1249 extensions and the plists 1242 — every
// format added since beta 6 (.cop, .mtc, .vt2, .sgc, .stim, .coco, …) was
// playable but invisible to "Open With", the open panel and the Dock. Hence
// this tool, which IMPORTS the registry rather than parsing it, like
// `third_party_notices.dart`, and a test that turns red on drift.
//
// ⚠️ Run through `flutter test`, not `dart run`: engines.dart pulls in
// rewamp_db.dart and with it the FFI plugin, which the plain Dart VM refuses to
// compile.
//
//   cd app && REWAMP_WRITE_PLIST=1 flutter test test/plist_extensions_sync_test.dart
//
// The rule for the set is deliberately simple so the test can state it:
// every extension of every engine, plus the local archive formats (an archive
// of modules is openable), plus `m3u`/`m3u8` (a playlist names what to play),
// plus the FM bank files (`wopl`/`wopn`: opening one imports it — AppShell).
// Extensions a SYSTEM type already owns (mp3, zip, …) stay in the list: the
// exported declaration is ignored for them, harmlessly, and they are ALSO
// claimed by their real UTI in `CFBundleDocumentTypes` — that part of the plist
// is hand-written and this tool does not touch it.
import 'package:rewamp/engines.dart';
import 'package:rewamp/rewamp_db.dart';

/// Playlist extensions the app opens as documents. Not an engine format.
const kPlaylistExts = <String>{'m3u', 'm3u8'};

/// FM instrument banks: opened to be IMPORTED (FmBankManager), not played.
const kFmBankExts = <String>{'wopl', 'wopn'};

/// Every extension the two plists must list, lower-case, plain-sorted.
List<String> bundledExtensions() {
  final s = <String>{};
  for (final e in kEngines) {
    s.addAll(e.formats.map((x) => x.toLowerCase()));
  }
  s.addAll(RewampDb.kLocalArchiveExts.map((x) => x.toLowerCase()));
  s.addAll(kPlaylistExts);
  s.addAll(kFmBankExts);
  return s.toList()..sort();
}

final _utiArray = RegExp(
    r'(<key>public\.filename-extension</key>\n(\s*)<array>\n)([\s\S]*?)(\n\s*</array>)');
final _docTypeArray = RegExp(
    r'(<key>CFBundleTypeExtensions</key>\n(\s*)<array>\n)([\s\S]*?)(\n\s*</array>)');

/// The plist with both extension arrays regenerated; everything else is kept
/// byte for byte. Returns the input unchanged when it already matches.
String rewritePlistExtensions(String xml, {List<String>? extensions}) {
  final exts = extensions ?? bundledExtensions();
  String fill(Match m) {
    // One indentation level deeper than the <array> line, as the file has it.
    final indent = '${m.group(2)}\t';
    final body = exts.map((e) => '$indent<string>$e</string>').join('\n');
    return '${m.group(1)}$body${m.group(4)}';
  }

  var out = xml.replaceAllMapped(_utiArray, fill);
  out = out.replaceAllMapped(_docTypeArray, fill);
  return out;
}

/// How many extension arrays [rewritePlistExtensions] would touch in [xml] —
/// a plist with none is not the file we think it is.
int plistExtensionArrayCount(String xml) =>
    _utiArray.allMatches(xml).length + _docTypeArray.allMatches(xml).length;
