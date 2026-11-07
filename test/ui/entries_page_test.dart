import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/entries/entries_page.dart';

import '../support/memory_storage.dart';

// Friday 2026-10-30, 15:00.
final now = DateTime(2026, 10, 30, 15);

const _data =
    '; header\n'
    'i 2026-10-28 09:00:00 personal:read\n'
    'o 2026-10-28 10:00:00 personal:read\n'
    'i 2026-10-29 09:00:00 work:acme:dev  fix login\n'
    'o 2026-10-29 12:00:00 work:acme:dev\n'
    'i 2026-10-30 09:00:00 work:acme:meet\n'
    'o 2026-10-30 09:30:00 work:acme:meet\n'
    'i 2026-10-30 14:00:00 work:globex:dev\n';

/// Runs [body] with the Entries page mounted on a phone-sized screen. The
/// widget tree owns the container and is unmounted at the end.
void entriesTest(
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
        child: const MaterialApp(home: EntriesPage()),
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

/// Position of a widget on screen, to check ordering.
double top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

Finder menuOf(String account) => find.descendant(
  of: find.widgetWithText(ListTile, account),
  matching: find.byType(PopupMenuButton<String>),
);

void main() {
  group('EntriesPage', () {
    entriesTest('asks for a folder when none is chosen', (tester, _) async {
      expect(find.byKey(const Key('choose-folder')), findsOneWidget);
    }, withFolder: false);

    entriesTest('empty directory', (tester, _) async {
      expect(find.text('No entries'), findsOneWidget);
    }, files: const {});

    entriesTest('groups by day, newest first, with the day total', (
      tester,
      _,
    ) async {
      expect(find.text('2026-10-30'), findsOneWidget);
      expect(find.text('2026-10-29'), findsOneWidget);
      expect(find.text('2026-10-28'), findsOneWidget);

      final order = [
        top(tester, find.text('2026-10-30')),
        top(tester, find.text('work:globex:dev')),
        top(tester, find.text('work:acme:meet')),
        top(tester, find.text('2026-10-29')),
        top(tester, find.text('work:acme:dev')),
        top(tester, find.text('2026-10-28')),
        top(tester, find.text('personal:read')),
      ];
      expect(order, [...order]..sort());

      // Oct 30: meet 0:30 + globex running 1:00 = 1:30.
      expect(
        find.descendant(
          of: find.widgetWithText(Row, '2026-10-30'),
          matching: find.text('1:30'),
        ),
        findsOneWidget,
      );
    });

    entriesTest('shows ranges, running entries and comments', (
      tester,
      _,
    ) async {
      expect(find.text('09:00 to 12:00\nfix login'), findsOneWidget);
      expect(find.text('since 14:00, running'), findsOneWidget);
      expect(find.text('1:00:00'), findsOneWidget); // live timer
    });

    entriesTest('filters by level and account prefix', (tester, _) async {
      // Level 1: work / personal.
      await tester.tap(find.byKey(const Key('filter-prefix')));
      await tester.pumpAndSettle();
      expect(find.text('personal').last, findsOneWidget);
      await tester.tap(find.text('work').last);
      await tester.pumpAndSettle();
      expect(find.text('personal:read'), findsNothing);
      expect(find.text('work:acme:dev'), findsOneWidget);

      // Level 2: work:acme / work:globex; the prefix resets.
      await tester.tap(find.byKey(const Key('filter-level')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Level 2').last);
      await tester.pumpAndSettle();
      expect(find.text('personal:read'), findsOneWidget); // prefix cleared

      await tester.tap(find.byKey(const Key('filter-prefix')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('work:globex').last);
      await tester.pumpAndSettle();
      expect(find.text('work:globex:dev'), findsOneWidget);
      expect(find.text('work:acme:dev'), findsNothing);
      expect(find.text('personal:read'), findsNothing);
    });

    entriesTest(
      'warns about problems in the files',
      (tester, storage) async {
        expect(find.text('1 problem in the files'), findsOneWidget);
        await tester.tap(find.byKey(const Key('warnings')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('2026-11.timeclock, line 1: malformed line'),
          findsOneWidget,
        );
      },
      files: const {'2026-10.timeclock': _data, '2026-11.timeclock': 'junk\n'},
    );

    entriesTest('Remove asks first and keeps the other lines', (
      tester,
      storage,
    ) async {
      await tester.tap(menuOf('work:acme:dev'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(find.text('Remove entry?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.text('2026-10.timeclock'), _data);

      await tester.tap(menuOf('work:acme:dev'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('work:acme:dev'), findsNothing);
      expect(
        storage.text('2026-10.timeclock'),
        _data.replaceAll(
          'i 2026-10-29 09:00:00 work:acme:dev  fix login\n'
              'o 2026-10-29 12:00:00 work:acme:dev\n',
          '',
        ),
      );
    });

    entriesTest('Edit changes the account and keeps the comment', (
      tester,
      storage,
    ) async {
      await tester.tap(menuOf('work:acme:dev'));
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

      expect(find.text('Edit entry'), findsNothing); // back on the list
      expect(find.text('work:acme:review'), findsOneWidget);
      expect(
        storage.text('2026-10.timeclock'),
        contains(
          'i 2026-10-29 09:00:00 work:acme:review  fix login\n'
          'o 2026-10-29 12:00:00 work:acme:review\n',
        ),
      );
    });

    entriesTest('Edit refuses an invalid account', (tester, storage) async {
      await tester.tap(menuOf('personal:read'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('account')), 'a  b');
      await tester.pump();
      expect(find.text('Account has two consecutive spaces'), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byKey(const Key('save'))).onPressed,
        isNull,
      );
    });

    entriesTest('Edit can mark a finished entry as running and back', (
      tester,
      storage,
    ) async {
      await tester.tap(menuOf('personal:read'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit-running')));
      await tester.pump();
      expect(find.byKey(const Key('edit-end')), findsNothing);
      await tester.tap(find.byKey(const Key('save')));
      await tester.pumpAndSettle();

      expect(
        storage.text('2026-10.timeclock'),
        isNot(contains('o 2026-10-28 10:00:00')),
      );
      expect(find.text('since 09:00, running'), findsOneWidget);
    });
  });
}
