import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/track/track_page.dart';

import '../support/memory_storage.dart';

// Friday 2026-10-30, 15:00.
final now = DateTime(2026, 10, 30, 15);

const _data =
    'i 2026-10-30 09:00:00 work:acme:dev\n'
    'o 2026-10-30 11:00:00 work:acme:dev\n'
    'i 2026-10-30 14:00:00 work:acme:meet\n';

/// Runs [body] with the Track page mounted on a phone-sized screen. The widget
/// tree owns the container and is unmounted at the end, which stops the clock
/// timer.
void trackTest(
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
        child: const MaterialApp(home: TrackPage()),
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
  group('TrackPage', () {
    trackTest('asks for a folder when none is chosen', (tester, storage) async {
      expect(find.byKey(const Key('choose-folder')), findsOneWidget);
      expect(find.text('Start now'), findsNothing);
    }, withFolder: false);

    trackTest('empty directory shows nothing running', (tester, storage) async {
      expect(find.text('Nothing running'), findsOneWidget);
    }, files: const {});

    trackTest('shows the running entry with a live timer', (
      tester,
      storage,
    ) async {
      // meet since 14:00, one hour at 15:00.
      expect(find.text('work:acme:meet'), findsWidgets);
      expect(find.text('1:00:00'), findsOneWidget);
    });

    trackTest('has no header, last entries or metrics', (
      tester,
      storage,
    ) async {
      expect(find.byType(AppBar), findsNothing);
      // The card has no title of its own, only the two buttons.
      expect(find.text('Start now'), findsOneWidget);
      expect(find.text('Start at...'), findsOneWidget);
      expect(find.text('Last entries'), findsNothing);
      expect(find.text('Today'), findsNothing);
    });

    trackTest('prefills the last used account', (tester, storage) async {
      expect(accountText(tester), 'work:acme:meet');
    });

    trackTest('suggests accounts, best first, and fills the field', (
      tester,
      storage,
    ) async {
      await tester.enterText(find.byKey(const Key('account')), 'dev');
      await tester.pumpAndSettle();
      // The suggestion list is the only place the account is listed.
      final tiles = find.widgetWithText(ListTile, 'work:acme:dev');
      expect(tiles, findsOneWidget);

      await tester.tap(tiles);
      await tester.pumpAndSettle();
      expect(accountText(tester), 'work:acme:dev');
    });

    trackTest('an invalid account shows the problem and disables Start', (
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

    trackTest('Start closes the keyboard', (tester, storage) async {
      final field = find.byKey(const Key('account'));
      await tester.enterText(field, 'personal:read');
      await tester.pump();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();

      expect(storage.text('2026-10.timeclock'), contains('personal:read'));
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
    });

    trackTest('Start now and Start at sit side by side', (
      tester,
      storage,
    ) async {
      final now = tester.getCenter(find.byKey(const Key('start')));
      final at = tester.getCenter(find.byKey(const Key('start-at')));
      expect(at.dx, greaterThan(now.dx));
      expect(at.dy, now.dy);
    });

    trackTest('Start at asks date and time in one dialog and starts', (
      tester,
      storage,
    ) async {
      await tester.enterText(find.byKey(const Key('account')), 'personal:read');
      await tester.pump();
      await tester.tap(find.byKey(const Key('start-at')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dt-hour')), '10');
      await tester.enterText(find.byKey(const Key('dt-minute')), '30');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();

      expect(
        storage.text('2026-10.timeclock'),
        endsWith('i 2026-10-30 10:30:00 personal:read\n'),
      );
    });

    trackTest('Start at in the future shows the problem and writes nothing', (
      tester,
      storage,
    ) async {
      await tester.enterText(find.byKey(const Key('account')), 'personal:read');
      await tester.pump();
      await tester.tap(find.byKey(const Key('start-at')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dt-hour')), '16');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();

      expect(find.text('Start is in the future'), findsOneWidget);
      expect(storage.text('2026-10.timeclock'), _data);
    });

    trackTest('has no comment field', (tester, storage) async {
      expect(find.byKey(const Key('comment')), findsNothing);
    });

    trackTest('Start writes a clock-in and shows it running', (
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

    trackTest('starting an account that already runs asks first', (
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

    trackTest('Stop clocks out and moves the entry to the last entries', (
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
    });

    trackTest('a file changed on disk is reported and reloaded', (
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
