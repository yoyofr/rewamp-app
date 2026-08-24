import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import 'app_snack.dart';
import 'l10n.dart';
import 'rewamp_db.dart' show SongNote;

/// Open an external link (same UX as the artist screen / credits): normalise
/// scheme-less urls to https, clipboard fallback when the launch is refused.
Future<void> openExternalLink(BuildContext context, String raw) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  var url = raw.trim();
  if (!url.contains('://')) url = 'https://$url';
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  } catch (_) {/* fall through to the clipboard */}
  if (opened) return;
  await Clipboard.setData(ClipboardData(text: url));
  AppSnack.showOn(messenger, l10n.settingsLinkCopied(url),
      duration: const Duration(seconds: 2));
}

/// Bottom sheet listing a song's demozoo notes (production notes first,
/// server-ordered). Each note: title + placed badge + Markdown body + a link
/// to its demozoo page.
Future<void> showSongNotesSheet(BuildContext context, List<SongNote> notes) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = ctx.l10n;
      final tt = Theme.of(ctx).textTheme;
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Text(l10n.contextNotes, style: tt.titleMedium),
              const SizedBox(height: 8),
              for (final n in notes) ...[
                Row(
                  children: [
                    if (n.title != null)
                      Expanded(
                        child: Text(n.title!,
                            style: tt.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      )
                    else
                      const Spacer(),
                    if (n.placed)
                      Tooltip(
                        message: l10n.notePlacedBadge,
                        child: Icon(Icons.emoji_events,
                            size: 16, color: cs.primary),
                      ),
                    if (n.url != null)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'demozoo.org',
                        onPressed: () => openExternalLink(ctx, n.url!),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                NoteMarkdown(
                  text: n.note,
                  onOpenLink: (u) => openExternalLink(ctx, u),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      );
    },
  );
}

// ── HTML → Markdown pre-pass ────────────────────────────────────────────────
// Part of the demozoo note corpus is HTML, not Markdown (a note authored on
// the site keeps its `<a href>`, `<br>`, `<b>`…). Rendered as literal text it
// showed the raw tags. Rather than pull in a Markdown+HTML engine, fold the
// handful of tags demozoo actually uses back into the Markdown this file
// already renders. Unknown tags are dropped, their text kept.

/// Cheap "is there anything to convert?" probe — a tag opener or an entity.
/// Notes without either (the majority) take the fast path unchanged.
final _kHtmlish = RegExp(r'<[a-zA-Z/!]|&(?:[a-zA-Z][a-zA-Z0-9]{1,9}|#\d{1,5}|#x[0-9a-fA-F]{1,5});');

final _kTag       = RegExp(r'<!--.*?-->|</?[a-zA-Z][^>]*>', dotAll: true);
final _kAnchor    = RegExp(
    '<a\\b[^>]*?href\\s*=\\s*["\']([^"\']+)["\'][^>]*>(.*?)</a\\s*>',
    caseSensitive: false, dotAll: true);
final _kBold      = RegExp(r'</?(?:b|strong)\s*>', caseSensitive: false);
final _kItalic    = RegExp(r'</?(?:i|em)\s*>', caseSensitive: false);
final _kBreak     = RegExp(r'<br\s*/?>', caseSensitive: false);
final _kBlockEnd  = RegExp(r'</(?:p|div|h[1-6]|tr|blockquote)\s*>',
    caseSensitive: false);
final _kListItem  = RegExp(r'<li\b[^>]*>', caseSensitive: false);
final _kItemEnd   = RegExp(r'</li\s*>', caseSensitive: false);
final _kListEnd   = RegExp(r'</(?:ul|ol)\s*>', caseSensitive: false);

const _kEntities = <String, String>{
  'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ',
  'hellip': '…', 'mdash': '—', 'ndash': '–', 'laquo': '«', 'raquo': '»',
  'lsquo': '‘', 'rsquo': '’', 'ldquo': '“', 'rdquo': '”', 'deg': '°',
  'eacute': 'é', 'egrave': 'è', 'agrave': 'à', 'ccedil': 'ç', 'uuml': 'ü',
  'ouml': 'ö', 'auml': 'ä', 'szlig': 'ß', 'copy': '©', 'trade': '™',
};

String _decodeEntities(String s) => s.replaceAllMapped(
      RegExp(r'&(#x[0-9a-fA-F]{1,5}|#\d{1,5}|[a-zA-Z][a-zA-Z0-9]{1,9});'),
      (m) {
        final body = m.group(1)!;
        if (body.startsWith('#x') || body.startsWith('#X')) {
          final code = int.tryParse(body.substring(2), radix: 16);
          return code == null ? m.group(0)! : String.fromCharCode(code);
        }
        if (body.startsWith('#')) {
          final code = int.tryParse(body.substring(1));
          return code == null ? m.group(0)! : String.fromCharCode(code);
        }
        return _kEntities[body.toLowerCase()] ?? m.group(0)!;
      },
    );

/// Folds the HTML subset demozoo emits into this file's Markdown dialect.
/// Entities are decoded LAST, so an escaped `&lt;b&gt;` stays visible text
/// instead of turning into a tag we would then strip.
String noteHtmlToMarkdown(String raw) {
  if (!_kHtmlish.hasMatch(raw)) return raw;   // fast path: nothing to do
  var s = raw;
  // Anchors first: their label may hold other tags, which we are about to
  // strip — extracting now keeps the visible text.
  s = s.replaceAllMapped(_kAnchor, (m) {
    final url = m.group(1)!.trim();
    var label = m.group(2)!.replaceAll(_kTag, '').trim();
    if (label.isEmpty) label = url;
    // A label with ] or ) would break the Markdown link syntax below.
    label = label.replaceAll(RegExp(r'[\]\[]'), '');
    return '[$label]($url)';
  });
  s = s
      .replaceAll(_kBold, '**')
      .replaceAll(_kItalic, '*')
      .replaceAll(_kBreak, '\n')
      .replaceAll(_kBlockEnd, '\n\n')
      .replaceAll(_kListItem, '\n• ')
      // </li> is a no-op: the NEXT <li> already opens a line, and mapping it
      // to a newline doubled every bullet gap.
      .replaceAll(_kItemEnd, '')
      .replaceAll(_kListEnd, '\n')
      .replaceAll(_kTag, '');
  s = _decodeEntities(s);
  return s
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Same fold, flattened to one line — for the collapsed previews that show a
/// note as plain text (party banner) and would otherwise print tags.
String noteToPlainLine(String raw) => noteHtmlToMarkdown(raw)
    // Link syntax has no place in a one-line preview: keep the LABEL and drop
    // the target, or a collapsed party note reads "organized by [Mystic
    // Bytes](https://www.sillyventure.eu/)" — the url eats the whole line.
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\((?:[^)\s]*)\)'), (m) => m[1]!)
    // replaceAllMapped, not replaceAll: the latter treats '$1' as literal text
    // and would print it instead of the captured word.
    .replaceAllMapped(RegExp(r'\*\*([^*]*)\*\*'), (m) => m[1]!)
    .replaceAll(RegExp(r'\s*\n\s*'), ' ')
    .trim();

/// Minimal Markdown renderer for demozoo notes (song/artist/group/party).
/// The corpus is plain prose with `[label](url)` links and the occasional
/// `**bold**` / `*italic*` — a full Markdown engine (and its dependency)
/// would be overkill — plus HTML notes, folded in by [noteHtmlToMarkdown].
/// Anything unrecognized renders as literal text.
class NoteMarkdown extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Opens a tapped link. Threaded in (not url_launcher here directly) so the
  /// caller keeps its own normalisation + clipboard-fallback UX.
  final void Function(String url) onOpenLink;

  const NoteMarkdown({
    super.key,
    required this.text,
    required this.onOpenLink,
    this.style,
  });

  @override
  State<NoteMarkdown> createState() => _NoteMarkdownState();
}

class _NoteMarkdownState extends State<NoteMarkdown> {
  final List<TapGestureRecognizer> _recognizers = [];
  /// widget.text with its HTML folded into Markdown — computed once per text
  /// change, not per build (_parse already runs on every repaint).
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = noteHtmlToMarkdown(widget.text);
  }

  @override
  void didUpdateWidget(NoteMarkdown old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _text = noteHtmlToMarkdown(widget.text);
  }

  // link | **bold** | *italic*
  static final _token = RegExp(
      r'\[([^\]]+)\]\(([^)\s]+)\)|\*\*([^*]+)\*\*|\*([^*\n]+)\*');

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _parse(TextStyle base, ColorScheme cs) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in _token.allMatches(_text)) {
      if (m.start > pos) {
        spans.add(TextSpan(text: _text.substring(pos, m.start)));
      }
      if (m.group(1) != null) {
        final url = m.group(2)!;
        final rec = TapGestureRecognizer()
          ..onTap = () => widget.onOpenLink(url);
        _recognizers.add(rec);
        spans.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(
              color: cs.primary, decoration: TextDecoration.underline),
          recognizer: rec,
        ));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(3),
            style: base.copyWith(fontWeight: FontWeight.w600)));
      } else {
        spans.add(TextSpan(
            text: m.group(4),
            style: base.copyWith(fontStyle: FontStyle.italic)));
      }
      pos = m.end;
    }
    if (pos < _text.length) {
      spans.add(TextSpan(text: _text.substring(pos)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.style ??
        Theme.of(context).textTheme.bodySmall ??
        const TextStyle();
    return Text.rich(TextSpan(style: base, children: _parse(base, cs)));
  }
}
