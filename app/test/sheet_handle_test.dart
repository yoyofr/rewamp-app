import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/sheet_handle.dart';

void main() {
  testWidgets('a tap on the handle closes the sheet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showHandleSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SingleChildScrollView(
              child: Column(children: [
                for (var i = 0; i < 60; i++) ListTile(title: Text('row $i')),
              ]),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(
        const DefaultMaterialLocalizations().closeButtonTooltip));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
  });
}
