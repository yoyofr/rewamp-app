import 'package:flutter/material.dart';

import 'browse_screen.dart' show PlaylistTracksScreen;
import 'competition_screen.dart';
import 'l10n.dart';
import 'rewamp_db.dart';

/// The gold/silver/bronze cup shown on a tune or an album that placed in a
/// demoparty competition, and the navigation behind it.
///
/// Tapping opens the competition. Two targets, in this order:
///   1. the compo's PLAYLIST when it has one (the ranked, playable list);
///   2. otherwise [CompetitionScreen] on `competition_id` — demo/intro compos
///      often have no playlist, and `competition_id` is always present. That
///      fallback is the whole reason the badge can exist on those tunes.
class PodiumBadge extends StatelessWidget {
  final CompoPodium podium;
  final double size;

  const PodiumBadge(this.podium, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: podiumLabel(context, podium),
      child: InkResponse(
        onTap: () => openPodium(context, podium),
        child: Icon(Icons.emoji_events,
            size: size, color: podiumColor(context, podium.rank)),
      ),
    );
  }
}

/// "1st — Assembly 1993 — PC Demo", or "music of Second Reality, 1st — …" when
/// the tune did not compete itself but the demo it soundtracks did.
String podiumLabel(BuildContext context, CompoPodium p) {
  final l10n = context.l10n;
  final place = switch (p.rank) {
    1 => l10n.podiumFirst,
    2 => l10n.podiumSecond,
    _ => l10n.podiumThird,
  };
  final compo = p.competitionName ?? p.playlistName ?? p.party ?? '';
  return switch (p.via) {
    // Album that IS the placed production, or tune that competed itself.
    'self' => compo.isEmpty ? place : '$place — $compo',
    // Album holding a placed tune.
    'song' => l10n.podiumContains(place, compo),
    // Tune whose demo placed.
    _ => p.production == null
        ? (compo.isEmpty ? place : '$place — $compo')
        : l10n.podiumMusicOf(p.production!, place, compo),
  };
}

/// Opens the competition behind a podium — playlist first, ranking screen
/// otherwise.
Future<void> openPodium(BuildContext context, CompoPodium p) async {
  final name = p.competitionName ?? p.playlistName ?? '';
  final playlistId = p.playlistId;
  if (playlistId != null && playlistId.isNotEmpty) {
    final onPlay = globalOnPlayOnlineSong;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaylistTracksScreen(
        playlist: Playlist(
            id: playlistId, slug: '', name: p.playlistName ?? name),
        onTap: onPlay ?? (c, r) async {},
      ),
    ));
    return;
  }
  final compId = p.competitionId;
  if (compId != null) {
    await openCompetition(context, competitionId: compId, title: name);
  }
}
