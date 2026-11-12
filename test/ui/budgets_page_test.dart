import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/settings/app_settings.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/budgets/budgets_page.dart';
import 'package:timetracker/ui/home_shell.dart';
import 'package:timetracker/ui/palette.dart';

import '../support/memory_storage.dart';

// Friday 2026-10-30, 15:00.
final now = DateTime(2026, 10, 30, 15);

const _data =
    'i 2026-10-30 09:00:00 work:acme:dev\n'
    'o 2026-10-30 11:00:00 work:acme:dev\n'
    'i 2026-10-12 09:00:00 work:acme:dev\n'
    'o 2026-10-12 10:00:00 work:acme:dev\n';

/// Runs [body] with [home] mounted on a phone-sized screen.
void budgetsTest(
  String name,
  Future<void> Function(WidgetTester tester, MemoryStorage storage) body, {
  Map<String, String> files = const {'2026-10.timeclock': _data},
  Map<String, Object> prefs = const {},
  Widget home = const BudgetsPage(),
}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final storage = MemoryStorage(files);
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          initialTreeUriProvider.overrideWithValue(
            'content://com.android.externalstorage.documents/tree/primary%3Atime',
          ),
          timeclockStorageProvider.overrideWithValue(storage),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(home: home),
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

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(BudgetsPage)));

void main() {
  group('BudgetsPage (split by month)', () {
    budgetsTest('the current month is there even with no budget', (
      tester,
      _,
    ) async {
      expect(find.byKey(const Key('window-2026-10')), findsOneWidget);
      expect(find.text('No goals'), findsOneWidget);
    });

    budgetsTest(
      'lists every window, newest first, with used and allowed time',
      (tester, storage) async {
        final oct = tester.getTopLeft(find.byKey(const Key('window-2026-10')));
        final sep = tester.getTopLeft(find.byKey(const Key('window-2026-09')));
        final every = tester.getTopLeft(
          find.byKey(const Key('window-Every week')),
        );
        expect(oct.dy, lessThan(sep.dy));
        expect(sep.dy, lessThan(every.dy));

        // October: work used 2:00 + 1:00.
        expect(
          find.descendant(
            of: find.byKey(const Key('budget-2026-10-work')),
            matching: find.text('3:00 / 20:00'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('budget-2026-09-work')),
            matching: find.text('0:00 / 99:00'),
          ),
          findsOneWidget,
        );
      },
      files: const {
        '2026-10.timeclock': _data,
        'budget.journal':
            '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    20h\n\n'
            '~ monthly from 2026-09-01 to 2026-10-01\n    (work)    99h\n\n'
            '~ weekly\n    (work)    10h\n',
      },
    );

    budgetsTest(
      'goals are yellow while in progress and green once achieved',
      (tester, storage) async {
        final brightness = Theme.of(tester.element(find.byType(BudgetsPage)))
            .brightness;
        Color? bar(String key) =>
            tester.widget<LinearProgressIndicator>(find.byKey(Key(key))).color;

        // October, work used 3:00. 20h: in progress. 3h: achieved.
        expect(
          bar('goal-bar-2026-10-work'),
          goalBarColor(achieved: false, brightness: brightness),
        );
        expect(
          find.byKey(const Key('goal-achieved-2026-10-work')),
          findsNothing,
        );
        expect(
          bar('goal-bar-2026-10-personal'),
          goalBarColor(achieved: true, brightness: brightness),
        );
        expect(
          find.byKey(const Key('goal-achieved-2026-10-personal')),
          findsOneWidget,
        );
        // Not red anywhere.
        expect(
          bar('goal-bar-2026-10-work'),
          isNot(
            Theme.of(tester.element(find.byType(BudgetsPage)))
                .colorScheme
                .error,
          ),
        );
      },
      files: const {
        '2026-10.timeclock':
            '$_data'
            'i 2026-10-05 09:00:00 personal:read\n'
            'o 2026-10-05 13:00:00 personal:read\n',
        'budget.journal':
            '~ monthly from 2026-10-01 to 2026-11-01\n'
            '    (work)    20h\n    (personal)    3h\n',
      },
    );

    budgetsTest(
      'a goal is achieved exactly at the target',
      (tester, storage) async {
        expect(
          find.byKey(const Key('goal-achieved-2026-10-work')),
          findsOneWidget,
        );
      },
      files: const {
        '2026-10.timeclock': _data,
        'budget.journal':
            '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    3h\n',
      },
    );

    budgetsTest('add writes a block bounded to the month', (
      tester,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('add-budget-2026-10')));
      await tester.pumpAndSettle();
      // The window decides the period: no period choice.
      expect(find.byKey(const Key('budget-period')), findsNothing);
      await tester.enterText(find.byKey(const Key('budget-project')), 'work');
      await tester.enterText(find.byKey(const Key('budget-hours')), '40');
      await tester.pump();
      await tester.tap(find.byKey(const Key('budget-save')));
      await tester.pumpAndSettle();

      expect(
        storage.text('budget.journal'),
        '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    40h\n',
      );
      expect(find.byKey(const Key('budget-2026-10-work')), findsOneWidget);
    });

    budgetsTest(
      'edit changes the hours, remove asks first then deletes the block',
      (tester, storage) async {
        await tester.tap(find.byKey(const Key('budget-2026-10-work')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('budget-hours')), '32.5');
        await tester.pump();
        await tester.tap(find.byKey(const Key('budget-save')));
        await tester.pumpAndSettle();
        expect(
          storage.text('budget.journal'),
          '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    32.5h\n',
        );

        await tester.tap(find.byKey(const Key('budget-remove-2026-10-work')));
        await tester.pumpAndSettle();
        expect(find.text('Remove goal?'), findsOneWidget);
        // Cancel keeps it.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          storage.text('budget.journal'),
          '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    32.5h\n',
        );

        await tester.tap(find.byKey(const Key('budget-remove-2026-10-work')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
        await tester.pumpAndSettle();
        expect(storage.text('budget.journal'), '');
        expect(find.text('No goals'), findsOneWidget);
      },
      files: const {
        '2026-10.timeclock': _data,
        'budget.journal':
            '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    20h\n',
      },
    );

    budgetsTest('Save is disabled for a bad budget', (tester, _) async {
      await tester.tap(find.byKey(const Key('add-budget-2026-10')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('budget-project')), 'a:b');
      await tester.enterText(find.byKey(const Key('budget-hours')), '5');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('budget-save')))
            .onPressed,
        isNull,
      );
    });

    budgetsTest('a budget for another period uses the picked date', (
      tester,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('add-period')));
      await tester.pumpAndSettle();
      // The picker opens on today; pick the 12th of the same month.
      await tester.tap(find.text('12'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2026-10'), findsWidgets);
      await tester.enterText(find.byKey(const Key('budget-project')), 'work');
      await tester.enterText(find.byKey(const Key('budget-hours')), '3');
      await tester.pump();
      await tester.tap(find.byKey(const Key('budget-save')));
      await tester.pumpAndSettle();
      expect(storage.text('budget.journal'), contains('(work)    3h'));
    });
  });

  group('BudgetsPage (no split)', () {
    budgetsTest('budgets repeat and the period is asked', (
      tester,
      storage,
    ) async {
      expect(find.byKey(const Key('add-period')), findsNothing);
      await tester.tap(find.byKey(const Key('add-recurring')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('budget-project')), 'work');
      await tester.enterText(find.byKey(const Key('budget-hours')), '10');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('budget-period')),
          matching: find.text('Week'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('budget-save')));
      await tester.pumpAndSettle();

      expect(storage.text('budget.journal'), '~ weekly\n    (work)    10h\n');
      expect(find.byKey(const Key('window-Every week')), findsOneWidget);
    }, prefs: const {'split': 'none'});
  });

  group('daily goals (in the Goals screen)', () {
    Future<void> addGoal(
      WidgetTester tester,
      String project,
      String hours,
    ) async {
      await tester.ensureVisible(find.byKey(const Key('add-daily-goal')));
      await tester.tap(find.byKey(const Key('add-daily-goal')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('budget-project')), project);
      await tester.enterText(find.byKey(const Key('budget-hours')), hours);
      await tester.pump();
      await tester.tap(find.byKey(const Key('budget-save')));
      await tester.pumpAndSettle();
    }

    budgetsTest('starts empty', (tester, storage) async {
      final c = containerOf(tester);
      await tester.ensureVisible(find.byKey(const Key('add-daily-goal')));
      expect(find.text('No daily goals'), findsOneWidget);
      expect(c.read(settingsProvider).dailyGoals, isEmpty);
    });

    budgetsTest('add saves the goal in the settings', (tester, storage) async {
      final c = containerOf(tester);
      await addGoal(tester, 'work', '8');
      expect(c.read(settingsProvider).dailyGoals, {
        'work': const Duration(hours: 8),
      });
      expect(find.text('8h a day'), findsOneWidget);
      expect(find.text('No daily goals'), findsNothing);
      // Kept in the app preferences, as JSON of seconds.
      expect(
        c.read(sharedPreferencesProvider).getString('dailyGoals'),
        '{"work":28800}',
      );
    });

    budgetsTest('the dialog does not ask for a period', (
      tester,
      storage,
    ) async {
      await tester.ensureVisible(find.byKey(const Key('add-daily-goal')));
      await tester.tap(find.byKey(const Key('add-daily-goal')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Add daily goal'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('budget-period')), findsNothing);
    });

    budgetsTest('goals are per project', (tester, storage) async {
      final c = containerOf(tester);
      await addGoal(tester, 'work', '6');
      await addGoal(tester, 'personal', '1.5');
      expect(c.read(settingsProvider).dailyGoals, {
        'work': const Duration(hours: 6),
        'personal': const Duration(hours: 1, minutes: 30),
      });
      expect(find.byKey(const Key('daily-goal-work')), findsOneWidget);
      expect(find.byKey(const Key('daily-goal-personal')), findsOneWidget);
    });

    budgetsTest('edit changes the hours, remove asks first', (
      tester,
      storage,
    ) async {
      final c = containerOf(tester);
      await tester.ensureVisible(find.byKey(const Key('daily-goal-work')));
      await tester.tap(find.byKey(const Key('daily-goal-work')));
      await tester.pumpAndSettle();
      expect(find.text('Edit daily goal'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('budget-hours')), '7.5');
      await tester.pump();
      await tester.tap(find.byKey(const Key('budget-save')));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).dailyGoals, {
        'work': const Duration(hours: 7, minutes: 30),
      });

      await tester.tap(find.byKey(const Key('daily-goal-remove-work')));
      await tester.pumpAndSettle();
      expect(find.text('Remove daily goal?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).dailyGoals, isNotEmpty);

      await tester.tap(find.byKey(const Key('daily-goal-remove-work')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('daily-goal-remove-confirm')));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).dailyGoals, isEmpty);
      expect(c.read(sharedPreferencesProvider).getString('dailyGoals'), '{}');
    }, prefs: const {'dailyGoals': '{"work":28800}'});

    budgetsTest('a bad project or hours cannot be saved', (
      tester,
      storage,
    ) async {
      await tester.ensureVisible(find.byKey(const Key('add-daily-goal')));
      await tester.tap(find.byKey(const Key('add-daily-goal')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('budget-project')), 'a:b');
      await tester.enterText(find.byKey(const Key('budget-hours')), '2');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('budget-save')))
            .onPressed,
        isNull,
      );
    });

    budgetsTest(
      'saved goals are read back, junk is ignored',
      (tester, storage) async {
        final c = containerOf(tester);
        expect(c.read(settingsProvider).dailyGoals, {
          'work': const Duration(hours: 2),
        });
      },
      prefs: const {'dailyGoals': '{"work":7200,"bad":"x","zero":0,"neg":-5}'},
    );

    budgetsTest('unreadable saved goals mean none', (tester, storage) async {
      final c = containerOf(tester);
      expect(c.read(settingsProvider).dailyGoals, isEmpty);
    }, prefs: const {'dailyGoals': 'not json'});
  });

  group('Goals tab', () {
    budgetsTest(
      'is always in the side bar and opens the goals',
      (tester, _) async {
        expect(find.text('Goals'), findsWidgets);
        await tester.tap(find.byIcon(Icons.flag_outlined));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('window-2026-10')), findsOneWidget);
      },
      prefs: const {},
      home: const HomeShell(),
    );

    budgetsTest(
      'a fresh install has it too',
      (tester, _) async {
        await tester.tap(find.byIcon(Icons.flag_outlined));
        await tester.pumpAndSettle();
        expect(find.text('No goals'), findsOneWidget);
      },
      prefs: const {},
      home: const HomeShell(),
      files: const {},
    );
  });
}
