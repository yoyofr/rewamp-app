// Rendering a CREDIT as the several artists it is.
//
// `artist_names` and `artist_ids` come back aligned from every songs RPC
// (mig 129) — one name, one uuid, per credited artist. Everything downstream
// used to flatten that into `artistLabel` ("A & B") and then, where a tap had
// to go somewhere, split the string back apart on `&`/`,`/`;`. That round trip
// loses the ids (so a homonym opens the wrong profile) and it guesses: an
// artist whose NAME contains an ampersand gets torn in half, and a credit the
// server rendered as one string ("aMUSiC and Leviathan") stays one bogus
// entity no separator can save.
//
// So: keep [SearchResult.artistLabel] for the places that genuinely need a
// String (the `tracks.artist` column, the media session, a marquee), and use
// these two widgets wherever the credit is shown to a human — [ArtistNames]
// inline, [ArtistChips] where the surface already speaks in chips.
import 'package:flutter/material.dart';

/// Opens an artist. [artistId] is the uuid when it is known — always prefer it,
/// the name alone cannot tell two homonyms apart.
typedef ArtistTapCallback = void Function(String name, {String? artistId});

/// The id credited to [names]\[i], or null when the row carried none (a local
/// file, a tag-derived credit, a server row predating mig 129).
String? artistIdAt(List<String> ids, int i) =>
    (i >= 0 && i < ids.length && ids[i].isNotEmpty) ? ids[i] : null;

/// Splits a credit STRING into names. Only for the sources that have no list:
/// a file's own ID3/Vorbis tag, a `tracks.artist` column. Never use it on a row
/// that carries `artist_names` — that list is the answer.
List<String> splitArtistCredit(String credit) => credit
    .split(RegExp(r'\s*[,;]\s*|\s*&\s*'))
    .map((a) => a.trim())
    .where((a) => a.isNotEmpty && a.toLowerCase() != 'null')
    .toSet()
    .toList();

/// The credit as inline text, each name its own tap target.
///
/// Wraps rather than scrolls: the player's own horizontal drag skips a track,
/// so a scrollable line inside it would eat that gesture. A single name should
/// generally be drawn by the caller instead (a marquee handles a long one
/// better than wrapping does) — [maxLines] is here for the rest.
class ArtistNames extends StatelessWidget {
  final List<String> names;
  final List<String> ids;
  final ArtistTapCallback? onTap;

  /// Per-name veto, for callers that only let a credit link out once the
  /// catalogue confirms it exists (the player does this for local files).
  final bool Function(String name)? isTappable;

  final TextStyle? style;
  final Color?     linkColor;
  final String     separator;
  final int        maxLines;

  const ArtistNames({
    super.key,
    required this.names,
    this.ids       = const [],
    this.onTap,
    this.isTappable,
    this.style,
    this.linkColor,
    this.separator = ' & ',
    this.maxLines  = 2,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final base = style ?? Theme.of(context).textTheme.bodySmall;
    final link = linkColor ?? cs.primary;

    final children = <Widget>[];
    for (int i = 0; i < names.length; i++) {
      final name    = names[i];
      final tappable = onTap != null && (isTappable?.call(name) ?? true);
      if (i > 0) {
        children.add(Text(separator,
            style: base?.copyWith(color: cs.onSurfaceVariant)));
      }
      children.add(
        // GestureDetector, not a recognizer inside a TextSpan: a recognizer has
        // to be disposed with the widget, and this is rebuilt on every player
        // tick.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tappable
              ? () => onTap!(name, artistId: artistIdAt(ids, i))
              : null,
          child: Text(
            name,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: base?.copyWith(
              color: tappable ? link : cs.onSurfaceVariant,
              decoration: tappable ? TextDecoration.underline : null,
            ),
          ),
        ),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// The credit as chips, for surfaces that already show tags/groups/productions
/// that way.
class ArtistChips extends StatelessWidget {
  final List<String> names;
  final List<String> ids;
  final ArtistTapCallback? onTap;
  final double spacing;

  const ArtistChips({
    super.key,
    required this.names,
    this.ids     = const [],
    this.onTap,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (int i = 0; i < names.length; i++)
          ActionChip(
            avatar: Icon(Icons.person_outline, size: 16, color: cs.primary),
            label: Text(names[i], maxLines: 1, overflow: TextOverflow.ellipsis),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onPressed: onTap == null
                ? null
                : () => onTap!(names[i], artistId: artistIdAt(ids, i)),
          ),
      ],
    );
  }
}
