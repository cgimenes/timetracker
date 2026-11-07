import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/home/home_page.dart';

import '../support/memory_storage.dart';

// Friday 2026-10-30, 15:00.
final now = DateTime(2026, 10, 30, 15);

const _data =
    'i 2026-10-30 09:00:00 work:acme:dev\n'
    'o 2026-10-30 11:00:00 work:acme:dev\n'
    'i 2026-10-30 14:00:00 work:acme:meet\n';

/// Runs [body] with the Home page mounted on a phone-sized screen. The widget
/// tree owns the container and is unmounted at the end, which stops the clock
/// timer.
void homeTest(
  String name,
  Future<void> Function(WidgetTester tester, MemoryStorage storage) body, {
  Map<String, String> files = const {'2026-10.timeclock': _data},
  bool withFolder = true,
}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final storage = MemoryStorage(files);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          initialTreeUriProvider.overrideWithValue(
            withFolder
                ? 'content://com.android.externalstorage.documents/tree/primary%3Atime'
                : null,
          ),
          timeclockStorageProvider.overrideWithValue(storage),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    try {
      await body(tester, storage);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}

String accountText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('account'))).controller!.text;

void main() {
  group('HomePage', () {
    homeTest('asks for a folder when none is chosen', (tester, storage) async {
      expect(find.byKey(const Key('choose-folder')), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    }, withFolder: false);

    homeTest('empty directory shows empty states', (tester, storage) async {
      expect(find.text('Nothing running'), findsOneWidget);
      expect(find.text('No entries yet'), findsOneWidget);
      expect(find.text('No time tracked'), findsNWidgets(3));
    }, files: const {});

    homeTest('shows running, last entries and metrics', (
      tester,
      storage,
    ) async {
      // Running: meet since 14:00, one hour at 15:00.
      expect(find.text('work:acme:meet'), findsWidgets);
      expect(find.text('1:00:00'), findsOneWidget);
      // Last entries: dev, two hours.
      expect(find.text('2026-10-30 09:00 to 11:00'), findsOneWidget);
      expect(find.text('2:00'), findsWidgets);
      // Metrics at level 1: work, 2h + 1h running, in all three periods.
      expect(find.text('Totals by account level 1'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('total-today'))).data,
        '3:00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('total-week'))).data,
        '3:00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('total-month'))).data,
        '3:00',
      );
      expect(find.text('work'), findsNWidgets(3));
    });

    homeTest('prefills the last used account', (tester, storage) async {
      expect(accountText(tester), 'work:acme:meet');
    });

    homeTest('suggests accounts, best first, and fills the field', (
      tester,
      storage,
    ) async {
      await tester.enterText(find.byKey(const Key('account')), 'dev');
      await tester.pumpAndSettle();
      // Two matches: the suggestion list (found first) and the Last entries row.
      final tiles = find.widgetWithText(ListTile, 'work:acme:dev');
      expect(tiles, findsNWidgets(2));

      await tester.tap(tiles.first);
      await tester.pumpAndSettle();
      expect(accountText(tester), 'work:acme:dev');
    });

    homeTest('an invalid account shows the problem and disables Start', (
      tester,
      storage,
    ) async {
      await tester.enterText(find.byKey(const Key('account')), 'a  b');
      await tester.pump();
      expect(find.text('Account has two consecutive spaces'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('start'))).onPressed,
        isNull,
      );

      await tester.enterText(find.byKey(const Key('account')), '');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('start'))).onPressed,
        isNull,
      );
    });

    homeTest('has no comment field', (tester, storage) async {
      expect(find.byKey(const Key('comment')), findsNothing);
    });

    homeTest('Start writes a clock-in and shows it running', (
      tester,
      storage,
    ) async {
      await tester.enterText(find.byKey(const Key('account')), 'personal:read');
      await tester.pump();
      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();

      expect(
        storage.text('2026-10.timeclock'),
        endsWith('i 2026-10-30 15:00:00 personal:read\n'),
      );
      expect(find.text('personal:read'), findsWidgets);
      expect(find.text('Nothing running'), findsNothing);
      // The account stays for the next start.
      expect(accountText(tester), 'personal:read');
    });

    homeTest('starting an account that already runs asks first', (
      tester,
      storage,
    ) async {
      // Field is prefilled with work:acme:meet, which is running.
      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();
      expect(find.text('Already running'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.text('2026-10.timeclock'), _data);

      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start anyway'));
      await tester.pumpAndSettle();
      expect(
        storage.text('2026-10.timeclock'),
        '${_data}i 2026-10-30 15:00:00 work:acme:meet\n',
      );
    });

    homeTest('Stop clocks out and moves the entry to the last entries', (
      tester,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pumpAndSettle();

      expect(
        storage.text('2026-10.timeclock'),
        '${_data}o 2026-10-30 15:00:00 work:acme:meet\n',
      );
      expect(find.text('Nothing running'), findsOneWidget);
      expect(find.text('2026-10-30 14:00 to 15:00'), findsOneWidget);
    });

    homeTest('a file changed on disk is reported and reloaded', (
      tester,
      storage,
    ) async {
      storage.externalWrite(
        '2026-10.timeclock',
        'i 2026-10-30 14:30:00 work:acme:meet\n',
      );
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pumpAndSettle();

      expect(find.textContaining('changed on disk'), findsOneWidget);
      // The screen now shows the file as it is: still running, since 14:30.
      expect(find.text('0:30:00'), findsOneWidget);
    });
  });
}
