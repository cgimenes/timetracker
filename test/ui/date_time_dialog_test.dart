import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/ui/ui_actions.dart';

import '../support/pick_time.dart';

// Friday 2026-10-30, 15:00.
final now = DateTime(2026, 10, 30, 15);

void main() {
  late DateTime? result;
  var asked = false;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(800, 2400),
    DateTime? initial,
    DateTime? first,
    DateTime? notAfter,
    DateTime? after,
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
                initial: initial ?? DateTime(2026, 10, 30, 9, 5),
                first: first ?? DateTime(2024),
                last: DateTime(2026, 10, 30),
                notAfter: notAfter,
                after: after,
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

  String time(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('dt-time-text'))).data!;

  bool selected(WidgetTester tester, String key) =>
      tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

  bool okEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('dt-ok'))).onPressed !=
      null;

  group('date', () {
    testWidgets('starts on the initial day with the calendar closed', (
      tester,
    ) async {
      await open(tester);
      expect(selected(tester, 'dt-today'), isTrue);
      expect(selected(tester, 'dt-yesterday'), isFalse);
      expect(find.byKey(const Key('dt-calendar')), findsNothing);
      expect(time(tester), '09:05');
    });

    testWidgets('day chips: today, yesterday and 2 days ago', (tester) async {
      await open(tester);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('2 days ago'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dt-yesterday')));
      await tester.pump();
      expect(selected(tester, 'dt-yesterday'), isTrue);
      expect(selected(tester, 'dt-today'), isFalse);
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 29, 9, 5));
    });

    testWidgets('2 days ago', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('dt-2days')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 28, 9, 5));
    });

    testWidgets('chips before the first allowed day are left out', (
      tester,
    ) async {
      await open(tester, first: DateTime(2026, 10, 29));
      expect(find.byKey(const Key('dt-today')), findsOneWidget);
      expect(find.byKey(const Key('dt-yesterday')), findsOneWidget);
      expect(find.byKey(const Key('dt-2days')), findsNothing);
    });

    testWidgets('Other date... opens the calendar, a day closes it again', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('dt-other')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dt-calendar')), findsOneWidget);

      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dt-calendar')), findsNothing);
      // The chip now names the day.
      expect(find.text('Mon 2026-10-12'), findsOneWidget);
      expect(selected(tester, 'dt-other'), isTrue);

      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 12, 9, 5));
    });

    testWidgets('an old initial day opens the calendar', (tester) async {
      await open(tester, initial: DateTime(2026, 9, 3, 8, 30));
      expect(find.byKey(const Key('dt-calendar')), findsOneWidget);
      expect(selected(tester, 'dt-today'), isFalse);
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 9, 3, 8, 30));
    });

    testWidgets('an initial day older than the first keeps its date', (
      tester,
    ) async {
      await open(
        tester,
        initial: DateTime(2020, 5, 5, 8),
        first: DateTime(2024),
      );
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2020, 5, 5, 8));
    });
  });

  group('time', () {
    testWidgets('the tile opens the Material clock and sets the time', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('dt-time')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      // The dialog behind stays open.
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(time(tester), '09:05');
      expect(find.byKey(const Key('dt-ok')), findsOneWidget);

      await pickTime(tester, 13, 45);
      expect(time(tester), '13:45');
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 30, 13, 45));
    });

    testWidgets('24 hour clock', (tester) async {
      await open(tester, initial: DateTime(2026, 10, 30, 21, 7));
      expect(time(tester), '21:07');
      await tester.tap(find.byKey(const Key('dt-time')));
      await tester.pumpAndSettle();
      expect(find.text('PM'), findsNothing);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
    });

    testWidgets('date and time together', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('dt-yesterday')));
      await tester.pump();
      await pickTime(tester, 23, 59);
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 29, 23, 59));
    });
  });

  group('limits', () {
    testWidgets('a moment after notAfter shows an error and blocks OK', (
      tester,
    ) async {
      await open(tester, notAfter: now);
      expect(find.byKey(const Key('dt-error')), findsNothing);
      expect(okEnabled(tester), isTrue);

      await pickTime(tester, 16, 0);
      expect(find.text('In the future'), findsOneWidget);
      expect(okEnabled(tester), isFalse);

      // Yesterday evening is fine.
      await tester.tap(find.byKey(const Key('dt-yesterday')));
      await tester.pump();
      expect(find.byKey(const Key('dt-error')), findsNothing);
      expect(okEnabled(tester), isTrue);
    });

    testWidgets('exactly notAfter is allowed', (tester) async {
      await open(tester, notAfter: now);
      await pickTime(tester, 15, 0);
      expect(okEnabled(tester), isTrue);
    });

    testWidgets('a moment not after "after" shows an error and blocks OK', (
      tester,
    ) async {
      final start = DateTime(2026, 10, 30, 9);
      await open(
        tester,
        initial: DateTime(2026, 10, 30, 12),
        notAfter: now,
        after: start,
      );
      expect(okEnabled(tester), isTrue);

      await pickTime(tester, 8, 30);
      expect(find.text('Must be after the start'), findsOneWidget);
      expect(okEnabled(tester), isFalse);

      await pickTime(tester, 9, 0);
      expect(okEnabled(tester), isFalse);
      await pickTime(tester, 9, 1);
      expect(okEnabled(tester), isTrue);
    });

    testWidgets('without limits any moment is accepted', (tester) async {
      await open(tester);
      await pickTime(tester, 23, 59);
      expect(okEnabled(tester), isTrue);
    });
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
      for (final key in ['dt-today', 'dt-other', 'dt-time', 'dt-ok']) {
        await tester.ensureVisible(find.byKey(Key(key)));
        expect(find.byKey(Key(key)), findsOneWidget);
      }
      // The calendar fits too, scrolling.
      await tester.tap(find.byKey(const Key('dt-other')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('dt-ok')));
    });
  }

  testWidgets('collapsed, the dialog needs no scrolling on a phone', (
    tester,
  ) async {
    await open(tester, size: const Size(360, 640));
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.position.maxScrollExtent, 0);
  });
}
