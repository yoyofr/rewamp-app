import 'package:flutter/widgets.dart';

/// Media progress and transport controls stay left-to-right in every language.
///
/// Material's bidirectionality guidance: playback controls and the progress of
/// a track are not mirrored in a right-to-left locale — they describe the
/// direction of time (tape, timeline), not of reading. Everything AROUND them
/// (titles, artwork, chrome) mirrors as usual; only these rows are pinned.
Widget ltrMedia(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);
