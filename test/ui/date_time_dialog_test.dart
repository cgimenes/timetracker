import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/ui/ui_actions.dart';

void main() {
  late DateTime? result;
  var asked = false;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    result = null;
    asked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await pickDateTime(
                context,
                initial: DateTime(2026, 10, 30, 9, 5),
                first: DateTime(2024),
                last: DateTime(2026, 10, 30),
              );
              asked = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('returns the date and typed time with one OK', (tester) async {
    await open(tester);
    expect(find.text('09'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('dt-hour')), '13');
    await tester.enterText(find.byKey(const Key('dt-minute')), '45');
    await tester.pump();
    await tester.tap(find.byKey(const Key('dt-ok')));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 30, 13, 45));
  });

  testWidgets('OK is disabled for an invalid time', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('dt-hour')), '24');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('dt-ok'))).onPressed,
      isNull,
    );
  });

  testWidgets('cancel returns null', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(asked, isTrue);
    expect(result, isNull);
  });
}
