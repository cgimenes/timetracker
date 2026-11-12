import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/ui/ui_actions.dart';

void main() {
  late DateTime? result;
  var asked = false;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(800, 2400),
  }) async {
    tester.view.physicalSize = size;
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

  for (final size in [const Size(360, 780), const Size(780, 360)]) {
    testWidgets('fits a $size screen without overflow', (tester) async {
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      // Calendar, time fields and buttons are all there and on screen.
      for (final finder in [
        find.byKey(const Key('dt-hour')),
        find.byKey(const Key('dt-minute')),
        find.byKey(const Key('dt-ok')),
      ]) {
        await tester.ensureVisible(finder);
        expect(finder, findsOneWidget);
      }
    });
  }
}
