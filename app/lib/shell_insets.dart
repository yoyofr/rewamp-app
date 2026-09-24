import 'package:flutter/widgets.dart';

/// Bottom room a scroll view must add for the FLOATING chrome (mini player +
/// nav bar) to have something to pass over without hiding it.
///
/// The chrome floats above the content instead of pushing it — that is the
/// whole point of the glass, it needs something moving underneath. AppShell
/// gives the space back by inflating `MediaQuery.padding.bottom` by exactly the
/// chrome's height, and a `ListView`/`GridView` with a NULL padding picks that
/// up on its own (`BoxScrollView` reads the media padding when none is given).
///
/// A scroll view that sets its own padding REPLACES it, and its last rows end
/// up unreachable under the glass — no amount of scrolling brings them out.
/// Every such scroll view under the shell therefore has to add it back, which
/// is what this is for:
///
/// ```dart
/// ListView(padding: shellInset(context, const EdgeInsets.all(12)), …)
/// ```
///
/// Only for VERTICAL scroll views under the shell. A horizontal rail has no
/// bottom to reach, and a modal sheet is not under the inflated MediaQuery.
///
/// ⚠️ It goes on the SCROLL VIEW's own `padding`, never on a `Padding` widget
/// that happens to be one of its CHILDREN. Applied to a child, the chrome's
/// whole height (mini player + nav bar) is injected in the MIDDLE of the list —
/// a fat empty band under that row — while the list's real bottom is unchanged.
/// Worse, a `ListView`/`GridView` whose own padding stays NULL already gets the
/// room by itself, so the call is redundant on top of being misplaced. Paid on
/// three screens (playlists, production, engine formats) where the first child
/// was the search field: the gap showed up between it and the row below.
EdgeInsets shellInset(BuildContext context, EdgeInsets base) =>
    base.copyWith(bottom: base.bottom + MediaQuery.of(context).padding.bottom);

/// The same room, as a LAST SLIVER for a `CustomScrollView`.
///
/// Only `BoxScrollView` (`ListView`, `GridView`) reads the media padding when
/// given none — a `CustomScrollView` reads nothing, ever. So the two screens
/// built from slivers scrolled their last rows under the glass even though they
/// set no padding at all, which is exactly the case that looks like it should
/// already work:
///
/// ```dart
/// CustomScrollView(slivers: [ …, shellInsetSliver(context) ])
/// ```
Widget shellInsetSliver(BuildContext context) => SliverToBoxAdapter(
      child: SizedBox(height: MediaQuery.of(context).padding.bottom),
    );
