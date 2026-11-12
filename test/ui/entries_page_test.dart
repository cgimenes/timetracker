import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/state/navigation.dart';
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

const _withFinishedGlobex =
    'i 2026-10-27 09:00:00 work:globex:dev\n'
    'o 2026-10-27 10:00:00 work:globex:dev\n'
    '$_data';

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

/// Taps the entry's row to show its actions, then taps the one with
/// [tooltip].
Future<void> rowAction(
  WidgetTester tester,
  String account,
  String tooltip,
) async {
  final tile = find.widgetWithText(ListTile, account);
  await tester.tap(
    find.descendant(of: tile, matching: find.byTooltip('Actions')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: tile, matching: find.byTooltip(tooltip)),
  );
  await tester.pumpAndSettle();
}

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
        top(tester, find.text('work:acme:meet')),
        top(tester, find.text('2026-10-29')),
        top(tester, find.text('work:acme:dev')),
        top(tester, find.text('2026-10-28')),
        top(tester, find.text('personal:read')),
      ];
      expect(order, [...order]..sort());

      // Oct 30: meet 0:30. The running globex entry is not counted.
      expect(
        find.descendant(
          of: find.widgetWithText(Row, '2026-10-30'),
          matching: find.text('0:30'),
        ),
        findsOneWidget,
      );
    });

    entriesTest('shows ranges and comments, not running entries', (
      tester,
      _,
    ) async {
      expect(find.text('09:00 to 12:00\nfix login'), findsOneWidget);
      expect(find.text('work:globex:dev'), findsNothing);
      expect(find.textContaining('running'), findsNothing);
    });

    entriesTest('has a search field and no level or prefix selects', (
      tester,
      _,
    ) async {
      expect(find.byKey(const Key('search')), findsOneWidget);
      expect(find.byKey(const Key('filter-level')), findsNothing);
      expect(find.byKey(const Key('filter-prefix')), findsNothing);
    });

    entriesTest('searches the account, ignoring case', (tester, _) async {
      await tester.enterText(find.byKey(const Key('search')), 'ACME');
      await tester.pump();
      expect(find.text('work:acme:dev'), findsOneWidget);
      expect(find.text('work:acme:meet'), findsOneWidget);
      expect(find.text('personal:read'), findsNothing);
    });

    entriesTest('every word must match, in any order', (tester, _) async {
      await tester.enterText(find.byKey(const Key('search')), 'dev acme');
      await tester.pump();
      expect(find.text('work:acme:dev'), findsOneWidget);
      expect(find.text('work:acme:meet'), findsNothing);
    });

    entriesTest('searches the comment too', (tester, _) async {
      await tester.enterText(find.byKey(const Key('search')), 'login');
      await tester.pump();
      expect(find.text('work:acme:dev'), findsOneWidget);
      expect(find.text('personal:read'), findsNothing);
    });

    entriesTest('day headers and totals follow the search', (tester, _) async {
      await tester.enterText(find.byKey(const Key('search')), 'read');
      await tester.pump();
      expect(find.text('2026-10-28'), findsOneWidget);
      expect(find.text('2026-10-29'), findsNothing);
      expect(find.text('2026-10-30'), findsNothing);
    });

    entriesTest('no match shows an empty list and clear brings it back', (
      tester,
      _,
    ) async {
      expect(find.byKey(const Key('search-clear')), findsNothing);
      await tester.enterText(find.byKey(const Key('search')), 'zzz');
      await tester.pump();
      expect(find.text('No entries'), findsOneWidget);

      await tester.tap(find.byKey(const Key('search-clear')));
      await tester.pump();
      expect(find.text('No entries'), findsNothing);
      expect(find.text('personal:read'), findsOneWidget);
      expect(find.byKey(const Key('search-clear')), findsNothing);
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
      await rowAction(tester, 'work:acme:dev', 'Remove');
      expect(find.text('Remove entry?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.text('2026-10.timeclock'), _data);

      await rowAction(tester, 'work:acme:dev', 'Remove');
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
      await rowAction(tester, 'work:acme:dev', 'Edit');
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
      await rowAction(tester, 'personal:read', 'Edit');

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
      await rowAction(tester, 'personal:read', 'Edit');

      await tester.tap(find.byKey(const Key('edit-running')));
      await tester.pump();
      expect(find.byKey(const Key('edit-end')), findsNothing);
      await tester.tap(find.byKey(const Key('save')));
      await tester.pumpAndSettle();

      expect(
        storage.text('2026-10.timeclock'),
        isNot(contains('o 2026-10-28 10:00:00')),
      );
      // Running now, so it moves to the Track tab.
      expect(find.text('personal:read'), findsNothing);
    });

    entriesTest('Start again now clocks in the same account', (
      tester,
      storage,
    ) async {
      await rowAction(tester, 'personal:read', 'Start again');
      await tester.tap(find.byKey(const Key('restart-now')));
      await tester.pumpAndSettle();

      expect(
        storage.text('2026-10.timeclock'),
        '${_data}i 2026-10-30 15:00:00 personal:read\n',
      );
      expect(find.text('Started personal:read'), findsOneWidget);
    });

    entriesTest('Start again at a picked time', (tester, storage) async {
      await rowAction(tester, 'personal:read', 'Start again');
      await tester.tap(find.byKey(const Key('restart-at')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dt-hour')), '10');
      await tester.enterText(find.byKey(const Key('dt-minute')), '15');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dt-ok')));
      await tester.pumpAndSettle();

      expect(
        storage.text('2026-10.timeclock'),
        '${_data}i 2026-10-30 10:15:00 personal:read\n',
      );
    });

    entriesTest('Start again cancelled writes nothing', (
      tester,
      storage,
    ) async {
      await rowAction(tester, 'personal:read', 'Start again');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(storage.text('2026-10.timeclock'), _data);
    });

    entriesTest(
      'Start again warns when the account already runs',
      (tester, storage) async {
        await rowAction(tester, 'work:globex:dev', 'Start again');
        await tester.tap(find.byKey(const Key('restart-now')));
        await tester.pumpAndSettle();
        expect(find.text('Already running'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(storage.text('2026-10.timeclock'), _withFinishedGlobex);
      },
      // A finished globex session, plus the running one in _data.
      files: const {'2026-10.timeclock': _withFinishedGlobex},
    );

    entriesTest('every row has a menu button, tapping the row does nothing', (
      tester,
      _,
    ) async {
      expect(find.byTooltip('Actions'), findsNWidgets(3));
      await tester.tap(find.widgetWithText(ListTile, 'personal:read'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Remove'), findsNothing);
    });

    entriesTest('the menu button shows the actions in the row, highlighted', (
      tester,
      _,
    ) async {
      final read = find.widgetWithText(ListTile, 'personal:read');
      final dev = find.widgetWithText(ListTile, 'work:acme:dev');
      Finder icon(Finder tile, String tooltip) =>
          find.descendant(of: tile, matching: find.byTooltip(tooltip));
      Finder actions(Finder tile) => find.descendant(
        of: tile,
        matching: find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              ['Start again', 'Edit', 'Remove'].contains(w.tooltip),
        ),
      );
      expect(actions(read), findsNothing);
      expect(find.descendant(of: read, matching: find.text('1:00')), findsOne);
      expect(tester.widget<ListTile>(read).selected, isFalse);

      await tester.tap(icon(read, 'Actions'));
      await tester.pumpAndSettle();
      expect(actions(read), findsNWidgets(3));
      expect(
        find.descendant(of: read, matching: find.text('1:00')),
        findsNothing,
      );
      // Highlighted background.
      final tile = tester.widget<ListTile>(read);
      expect(tile.selected, isTrue);
      expect(
        tile.selectedTileColor,
        Theme.of(tester.element(read)).colorScheme.secondaryContainer,
      );
      expect(tester.widget<ListTile>(dev).selected, isFalse);

      // The three icons and the menu button sit in the row, level.
      final y = tester.getCenter(icon(read, 'Edit')).dy;
      expect(tester.getCenter(icon(read, 'Start again')).dy, y);
      expect(tester.getCenter(icon(read, 'Remove')).dy, y);
      expect(tester.getCenter(icon(read, 'Actions')).dy, y);
      expect(y, tester.getCenter(read).dy);
      // Menu button is the last thing on the right.
      expect(
        tester.getCenter(icon(read, 'Actions')).dx,
        greaterThan(tester.getCenter(icon(read, 'Remove')).dx),
      );

      // Another row takes over.
      await tester.tap(icon(dev, 'Actions'));
      await tester.pumpAndSettle();
      expect(actions(read), findsNothing);
      expect(actions(dev), findsNWidgets(3));
      expect(tester.widget<ListTile>(read).selected, isFalse);
      expect(tester.widget<ListTile>(dev).selected, isTrue);

      // The menu button again hides them.
      await tester.tap(icon(dev, 'Actions'));
      await tester.pumpAndSettle();
      expect(actions(dev), findsNothing);
      expect(tester.widget<ListTile>(dev).selected, isFalse);
    });

    entriesTest('changing the search closes the open row', (tester, _) async {
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'personal:read'),
          matching: find.byTooltip('Actions'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search')), 'read');
      await tester.pump();
      expect(find.byTooltip('Edit'), findsNothing);
    });

    entriesTest('after Start again the user goes to the Track screen', (
      tester,
      storage,
    ) async {
      final c = ProviderScope.containerOf(
        tester.element(find.byType(EntriesPage)),
      );
      c.read(homeTabProvider.notifier).select(HomeTab.entries);

      await rowAction(tester, 'personal:read', 'Start again');
      await tester.tap(find.byKey(const Key('restart-now')));
      await tester.pumpAndSettle();

      expect(c.read(homeTabProvider), HomeTab.track);
    });

    entriesTest('cancelling Start again stays on the Entries screen', (
      tester,
      storage,
    ) async {
      final c = ProviderScope.containerOf(
        tester.element(find.byType(EntriesPage)),
      );
      c.read(homeTabProvider.notifier).select(HomeTab.entries);

      await rowAction(tester, 'personal:read', 'Start again');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(c.read(homeTabProvider), HomeTab.entries);
    });

    entriesTest('declining the duplicate warning stays on Entries', (
      tester,
      storage,
    ) async {
      final c = ProviderScope.containerOf(
        tester.element(find.byType(EntriesPage)),
      );
      c.read(homeTabProvider.notifier).select(HomeTab.entries);

      await rowAction(tester, 'work:globex:dev', 'Start again');
      await tester.tap(find.byKey(const Key('restart-now')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(c.read(homeTabProvider), HomeTab.entries);
    }, files: const {'2026-10.timeclock': _withFinishedGlobex});
  });
}
