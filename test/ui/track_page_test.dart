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
      // The suggestion list (dense tiles); Quick start lists it too.
      final tiles = find.byWidgetPredicate(
        (w) =>
            w is ListTile &&
            w.dense == true &&
            (w.title as Text).data == 'work:acme:dev',
      );
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

    trackTest('the menu offers Stop at, Edit and Cancel entry', (
      tester,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('stop-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Stop at...'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel entry'), findsOneWidget);
    });

    trackTest('Edit opens the entry and saving changes the running one', (
      tester,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('stop-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit entry'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('account')),
        'work:acme:review',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('save')));
      await tester.pumpAndSettle();

      expect(find.text('Edit entry'), findsNothing);
      expect(
        storage.text('2026-10.timeclock'),
        endsWith('i 2026-10-30 14:00:00 work:acme:review\n'),
      );
      // In the running list and as a quick start button.
      expect(find.text('work:acme:review'), findsNWidgets(2));
    });

    trackTest('Cancel entry asks first, then removes it without a clock-out', (
      tester,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('stop-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel entry'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel entry?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('keep-running')));
      await tester.pumpAndSettle();
      expect(storage.text('2026-10.timeclock'), _data);
      expect(find.text('Nothing running'), findsNothing);

      await tester.tap(find.byKey(const Key('stop-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-confirm')));
      await tester.pumpAndSettle();

      expect(
        storage.text('2026-10.timeclock'),
        'i 2026-10-30 09:00:00 work:acme:dev\n'
        'o 2026-10-30 11:00:00 work:acme:dev\n',
      );
      expect(find.text('Nothing running'), findsOneWidget);
    });

    trackTest(
      'quick start lists the three most frecent accounts',
      (tester, storage) async {
        final quick = find.byKey(const Key('quick-start'));
        expect(quick, findsOneWidget);
        // Frecency over the three accounts in the data: dev, then meet; the
        // third is the next one by score.
        expect(
          find.descendant(of: quick, matching: find.byType(ListTile)),
          findsNWidgets(3),
        );
        expect(
          find.descendant(of: quick, matching: find.text('Quick start')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('quick-work:acme:dev')), findsOneWidget);
        expect(find.byKey(const Key('quick-work:acme:meet')), findsOneWidget);
        expect(find.byKey(const Key('quick-personal:read')), findsOneWidget);
      },
      files: const {
        '2026-10.timeclock':
            'i 2026-10-30 09:00:00 work:acme:dev\n'
            'o 2026-10-30 10:00:00 work:acme:dev\n'
            'i 2026-10-29 09:00:00 work:acme:dev\n'
            'o 2026-10-29 10:00:00 work:acme:dev\n'
            'i 2026-10-28 09:00:00 work:acme:meet\n'
            'o 2026-10-28 10:00:00 work:acme:meet\n'
            'i 2026-10-20 09:00:00 personal:read\n'
            'o 2026-10-20 10:00:00 personal:read\n'
            'i 2026-06-01 09:00:00 old:thing\n'
            'o 2026-06-01 10:00:00 old:thing\n',
      },
    );

    trackTest(
      'only three buttons even with more accounts',
      (tester, storage) async {
        expect(find.byKey(const Key('quick-old:thing')), findsNothing);
      },
      files: const {
        '2026-10.timeclock':
            'i 2026-10-30 09:00:00 a\no 2026-10-30 10:00:00 a\n'
            'i 2026-10-29 09:00:00 b\no 2026-10-29 10:00:00 b\n'
            'i 2026-10-28 09:00:00 c\no 2026-10-28 10:00:00 c\n'
            'i 2026-06-01 09:00:00 old:thing\no 2026-06-01 10:00:00 old:thing\n',
      },
    );

    trackTest('a quick start button starts that account now', (
      tester,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('quick-work:acme:dev')));
      await tester.pumpAndSettle();
      expect(
        storage.text('2026-10.timeclock'),
        endsWith('i 2026-10-30 15:00:00 work:acme:dev\n'),
      );
      expect(find.text('Nothing running'), findsNothing);
    });

    trackTest('quick start asks first when the account already runs', (
      tester,
      storage,
    ) async {
      // work:acme:meet runs in the default data.
      await tester.tap(find.byKey(const Key('quick-work:acme:meet')));
      await tester.pumpAndSettle();
      expect(find.text('Already running'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.text('2026-10.timeclock'), _data);
    });

    trackTest('no history, no quick start buttons', (tester, storage) async {
      expect(find.byKey(const Key('quick-start')), findsNothing);
    }, files: const {});
  });
}
