// The queue panel header has to survive the NARROWEST place it is shown: the
// player's overlay on a phone, ~259 px. It did not — a text "Edit" button next
// to the four existing icons overflowed by 42 px, and the title (a bare Text in
// a Row) wrapped instead of ellipsing, which is what made the row 312 px tall.
//
// Nothing here checks a pixel value; it checks that the header does not
// overflow at the widths the app actually uses, which is what an overflow
// assertion tells you at runtime and nothing tells you at review time.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/player_screen.dart';
import 'package:rewamp/player_controller.dart';
import 'package:rewamp/l10n/app_localizations.dart';

QueueEntry _entry(int i) =>
    QueueEntry(id: i, title: 'Track number $i', artist: 'Some artist');

/// Stands in for AppShell: the panel does not own the queue, so a removal has
/// to come back as a shorter list from outside.
class _QueueHost extends StatefulWidget {
  final List<QueueEntry> initial;
  const _QueueHost(this.initial);
  @override
  State<_QueueHost> createState() => _QueueHostState();
}

class _QueueHostState extends State<_QueueHost> {
  late final _queue = List<QueueEntry>.of(widget.initial);

  @override
  Widget build(BuildContext context) => QueuePanel(
        cs: ColorScheme.fromSeed(seedColor: Colors.indigo),
        queue: _queue,
        currentIdx: 0,
        onTap: (_) {},
        onReorder: (_, __) {},
        onRemove: (idx) => setState(() {
          final kept = <QueueEntry>[];
          for (var i = 0; i < _queue.length; i++) {
            if (!idx.contains(i)) kept.add(_queue[i]);
          }
          _queue
            ..clear()
            ..addAll(kept);
        }),
      );
}

Widget _host(Widget child, double width) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: 600, child: child),
        ),
      ),
    );

void main() {
  for (final width in <double>[259, 320, 400]) {
    testWidgets('queue header fits at ${width.toInt()} px', (tester) async {
      final cs = ColorScheme.fromSeed(seedColor: Colors.indigo);
      await tester.pumpWidget(_host(
        QueuePanel(
          cs: cs,
          queue: List.generate(6, _entry),
          currentIdx: 1,
          title: 'File d\'attente',
          onTap: (_) {},
          onClose: () {},
          onToggleShuffle: () {},
          onCycleLoop: () {},
          onAddToPlaylist: () {},
          onClearQueue: () {},
          onReorder: (_, __) {},
          onRemove: (_) {},
        ),
        width,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // …and in edit mode, where the header swaps in its own actions.
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Checkbox), findsWidgets);
    });
  }

  testWidgets('a swiped row leaves no state on the one that takes its place',
      (tester) async {
    await tester.pumpWidget(_host(_QueueHost(List.generate(4, _entry)), 360));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Track number 2'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Track number 2'), findsNothing);
    expect(find.text('Track number 3'), findsOneWidget);
    // The rows must be keyed on the ITEM. With index keys the row that shifts
    // up inherits the key of the one just dismissed — and with it Flutter's
    // "already dismissed" state, which is what left the red delete background
    // sitting over the track that moved into the slot.
    final keys = tester
        .widgetList<Dismissible>(find.byType(Dismissible))
        .map((d) => (d.key! as ValueKey).value)
        .toList();
    expect(keys, [0, 1, 3]);
  });

  testWidgets('rows carry a drag handle and a swipe-to-remove', (tester) async {
    final removed = <Set<int>>[];
    final cs = ColorScheme.fromSeed(seedColor: Colors.indigo);
    await tester.pumpWidget(_host(
      QueuePanel(
        cs: cs,
        queue: List.generate(4, _entry),
        currentIdx: 0,
        onTap: (_) {},
        onReorder: (_, __) {},
        onRemove: removed.add,
      ),
      360,
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(4));

    await tester.drag(find.text('Track number 2'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(removed, [
      {2}
    ]);
  });

  // Vider la file: geste irréversible qui ARRÊTE aussi la lecture, donc il
  // passe par une confirmation. Le test vérifie les deux moitiés — que rien ne
  // parte sur « Annuler », et que le rappel parte sur la confirmation.
  group('vider la file', () {
    Future<void> pumpPanel(WidgetTester tester, List<String> log) =>
        tester.pumpWidget(_host(
          QueuePanel(
            cs: ColorScheme.fromSeed(seedColor: Colors.indigo),
            queue: List.generate(3, _entry),
            currentIdx: 0,
            title: 'File d\'attente',
            onTap: (_) {},
            onClose: () {},
            onClearQueue: () => log.add('cleared'),
            onReorder: (_, __) {},
            onRemove: (_) {},
          ),
          360,
        ));

    testWidgets('« Annuler » ne vide rien', (tester) async {
      final log = <String>[];
      await pumpPanel(tester, log);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.playlist_remove));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    });

    testWidgets('la confirmation appelle le rappel UNE fois', (tester) async {
      final log = <String>[];
      await pumpPanel(tester, log);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.playlist_remove));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(log, ['cleared']);
    });

    testWidgets('une file VIDE n\'affiche pas le bouton', (tester) async {
      await tester.pumpWidget(_host(
        QueuePanel(
          cs: ColorScheme.fromSeed(seedColor: Colors.indigo),
          queue: const [],
          currentIdx: 0,
          title: 'File d\'attente',
          onClose: () {},
          onClearQueue: () {},
        ),
        360,
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.playlist_remove), findsNothing);
    });
  });

  // Le bandeau passe à DEUX lignes quand la largeur ne suffit plus: le titre
  // garde sa ligne avec la fermeture, les actions passent dessous. Le critère
  // qui compte est « rien ne déborde ET le titre reste lisible », pas un pixel.
  testWidgets('bandeau étroit: deux lignes, rien ne déborde', (tester) async {
    final cs = ColorScheme.fromSeed(seedColor: Colors.indigo);
    await tester.pumpWidget(_host(
      QueuePanel(
        cs: cs,
        queue: List.generate(4, _entry),
        currentIdx: 0,
        title: 'File d\'attente',
        onTap: (_) {},
        onClose: () {},
        onToggleShuffle: () {},
        onCycleLoop: () {},
        onAddToPlaylist: () {},
        onClearQueue: () {},
        onReorder: (_, __) {},
        onRemove: (_) {},
      ),
      280, // la barre latérale du mode bureau
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Le titre n'est pas écrasé à quelques pixels par six icônes: sur deux
    // lignes il dispose de toute la largeur moins la seule fermeture.
    final titleWidth = tester.getSize(find.text('File d\'attente')).width;
    expect(titleWidth, greaterThan(150));
    // Et les six actions sont bien toutes là.
    expect(find.byIcon(Icons.checklist), findsOneWidget);
    expect(find.byIcon(Icons.playlist_add), findsOneWidget);
    expect(find.byIcon(Icons.playlist_remove), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
