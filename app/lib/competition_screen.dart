import 'package:flutter/material.dart';

import 'app_snack.dart';
import 'artwork_image.dart';
import 'l10n.dart';
import 'production_screen.dart' show globalOnOpenProduction;
import 'rewamp_db.dart';
import 'track_options_sheet.dart'
    show showPlayChoiceSheet, PlayChoice, globalOnQueueAdd, globalOnPlayNowSong;

/// The ranking of one demoparty competition (`get_competition_entries`).
///
/// A competition is NOT a playlist: it lists PRODUCTIONS in ranked order, and
/// only some of them have music in the catalogue. Many compos have no playlist
/// at all (demo/intro compos especially), which is exactly why this screen
/// exists — it is the tap target of a podium badge whose `playlist_id` is
/// absent, and of a `kind='competition'` featured card.
class CompetitionScreen extends StatefulWidget {
  final int competitionId;
  final String title;
  /// Why the user got here (the featured rail's reason), shown under the title.
  final String? note;
  /// Play path for a tune of the catalogue.
  final Future<void> Function(BuildContext, SearchResult)? onPlayOnline;

  const CompetitionScreen({
    super.key,
    required this.competitionId,
    required this.title,
    this.note,
    this.onPlayOnline,
  });

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

/// Opens a competition from anywhere, keeping one navigation path.
Future<void> openCompetition(BuildContext context,
    {required int competitionId, required String title, String? note}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => CompetitionScreen(
      competitionId: competitionId,
      title: title,
      note: note,
      onPlayOnline: globalOnPlayOnlineSong,
    ),
  ));
}

/// Set by AppShell — the download-and-play path, same hook style as
/// [globalOnOpenProduction].
Future<void> Function(BuildContext, SearchResult)? globalOnPlayOnlineSong;

class _CompetitionScreenState extends State<CompetitionScreen> {
  List<CompetitionEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await RewampDb.competitionEntries(widget.competitionId);
    if (!mounted) return;
    setState(() { _entries = rows; _loading = false; });
  }

  /// Tap on an entry: play it when the catalogue has exactly one tune for it,
  /// otherwise open the production (which lists its tunes, videos and albums).
  Future<void> _openEntry(CompetitionEntry e) async {
    if (e.songIds.length == 1 && widget.onPlayOnline != null) {
      final ctx = await RewampDb.getSongContext(e.songIds.first);
      if (!mounted) return;
      if (ctx != null) {
        // Un tap qui ÉCRASERAIT la file demande d'abord, comme partout
        // ailleurs; la popup répond `now` sans s'afficher quand rien ne joue.
        final choice = await showPlayChoiceSheet(context,
            title: ctx.song.displayTitle);
        if (choice == null || !mounted) return;
        if (choice != PlayChoice.now) {
          await globalOnQueueAdd?.call(ctx.song,
              atEnd: choice == PlayChoice.end);
          return;
        }
        // REMPLACE la file — voir song_tile: onPlayOnline joue sans la toucher.
        final playNow = globalOnPlayNowSong;
        if (playNow != null) {
          await playNow(ctx.song);
          return;
        }
        await widget.onPlayOnline!(context, ctx.song);
        return;
      }
    }
    if (e.productionId != null) {
      globalOnOpenProduction?.call(e.productionId!, title: e.title);
      return;
    }
    if (mounted) AppSnack.show(context, context.l10n.competitionEntryNoMusic);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Text(l10n.competitionEmpty,
                      style: TextStyle(color: cs.outline)))
              : ListView.builder(
                  itemCount: _entries.length + (widget.note == null ? 0 : 1),
                  itemBuilder: (_, i) {
                    if (widget.note != null && i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(widget.note!,
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      );
                    }
                    final e = _entries[i - (widget.note == null ? 0 : 1)];
                    return _entryTile(e);
                  },
                ),
    );
  }

  Widget _entryTile(CompetitionEntry e) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final rank = e.rankNumber;
    final subtitle = [
      if (e.groups.isNotEmpty) e.groups.join(', '),
      if (e.songCount > 0) l10n.competitionEntryTunes(e.songCount),
    ].join(' · ');

    return ListTile(
      leading: SizedBox(
        width: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              // The ranking is shown AS DEMOZOO GIVES IT ("2=" for a tie), not
              // recomputed from the row order.
              child: (rank != null && rank <= 3)
                  ? Icon(Icons.emoji_events,
                      size: 18, color: podiumColor(context, rank))
                  : Text(e.ranking,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 28, height: 28,
              child: ArtworkImage(
                url: e.artworkUrl,
                size: 28,
                borderRadius: BorderRadius.circular(4),
                placeholder: Icon(Icons.videogame_asset_outlined,
                    size: 16, color: cs.primary),
              ),
            ),
          ],
        ),
      ),
      title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (e.hasVideo)
            Icon(Icons.play_circle_outline, size: 18, color: cs.primary),
          if (e.songCount > 0) ...[
            const SizedBox(width: 6),
            Icon(Icons.music_note, size: 18, color: cs.onSurfaceVariant),
          ],
        ],
      ),
      onTap: () => _openEntry(e),
    );
  }
}

/// Gold / silver / bronze. Shared by every podium badge in the app so the three
/// colours are defined once.
Color podiumColor(BuildContext context, int rank) => switch (rank) {
      1 => const Color(0xFFD4AF37),
      2 => const Color(0xFFAEB4BB),
      _ => const Color(0xFFB0703C),
    };
