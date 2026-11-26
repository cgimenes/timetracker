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

    group('days progress', () {
      const files = {
        '2026-10.timeclock': _data,
        'budget.journal':
            '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    55h\n'
            '    (personal)    10h\n\n'
            '~ daily\n    (work)    8h\n',
      };

      Finder days(String account) =>
          find.byKey(Key('goal-days-2026-10-$account'));

      budgetsTest(
        'shows done and needed days of the daily goal',
        (tester, _) async {
          // Work used 3:00 of a 1.5h day: 2 days done, 55h / 1.5h -> 37.
          expect(tester.widget<Text>(days('work')).data, '[2/37]');
          expect(days('personal'), findsNothing);
        },
        files: files,
        prefs: const {'goalDays': true, 'dailyGoals': '{"work":5400}'},
      );

      budgetsTest(
        'is hidden when the setting is off',
        (tester, _) async {
          expect(days('work'), findsNothing);
        },
        files: files,
        prefs: const {'dailyGoals': '{"work":5400}'},
      );

      budgetsTest(
        'is hidden on daily goals',
        (tester, _) async {
          expect(
            find.byKey(const Key('goal-days-Every day-work')),
            findsNothing,
          );
        },
        files: files,
        prefs: const {'goalDays': true, 'dailyGoals': '{"work":5400}'},
      );
    });

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
      await tester.enterText(find.byKey(const Key('budget-account')), 'work');
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
      await tester.enterText(find.byKey(const Key('budget-account')), 'a  b');
      await tester.enterText(find.byKey(const Key('budget-hours')), '5');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('budget-save')))
            .onPressed,
        isNull,
      );
    });

    budgetsTest(
      'the where-goals-are-saved note is in the first goals card',
      (tester, _) async {
        final note = find.byKey(const Key('goals-note'));
        expect(note, findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('window-2026-10')),
            matching: note,
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: note,
            matching: find.textContaining('budget.journal'),
          ),
          findsOneWidget,
        );
        // Said once: nowhere else on the screen.
        expect(find.textContaining('Goals are saved in'), findsOneWidget);
      },
      files: const {
        '2026-10.timeclock': _data,
        'budget.journal':
            '~ monthly from 2026-09-01 to 2026-10-01\n    (work)    9h\n',
      },
    );

    budgetsTest('Add daily goal looks like Add goal', (tester, _) async {
      final daily = find.byKey(const Key('add-daily-goal'));
      final goal = find.byKey(const Key('add-budget-2026-10'));
      expect(tester.widget(daily), isA<TextButton>());
      expect(tester.widget(goal), isA<TextButton>());
      expect(
        find.descendant(of: daily, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
      // Same position inside their cards, same height.
      expect(tester.getRect(daily).left, tester.getRect(goal).left);
      expect(tester.getRect(daily).height, tester.getRect(goal).height);
      expect(
        find.descendant(of: daily, matching: find.text('Add daily goal')),
        findsOneWidget,
      );
    });

    budgetsTest('there is no way to pick another period', (tester, _) async {
      expect(find.byKey(const Key('add-period')), findsNothing);
      expect(find.text('Goals for another period'), findsNothing);
      expect(find.byIcon(Icons.event), findsNothing);
      // Only the cards that exist, each with its own Add goal.
      expect(find.byKey(const Key('add-budget-2026-10')), findsOneWidget);
    });
  });

  group('BudgetsPage (no split)', () {
    budgetsTest(
      'with no card the note is shown on its own',
      (tester, _) async {
        expect(find.byKey(const Key('goals-note')), findsNothing);
        expect(find.textContaining('Goals are saved in'), findsOneWidget);
      },
      prefs: const {'split': 'none'},
      files: const {},
    );

    budgetsTest('budgets repeat and the period is asked', (
      tester,
      storage,
    ) async {
      expect(find.byKey(const Key('add-period')), findsNothing);
      await tester.tap(find.byKey(const Key('add-recurring')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('budget-account')), 'work');
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
      await tester.enterText(find.byKey(const Key('budget-account')), project);
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
      // work did 2:00 today (09:00 to 11:00).
      expect(find.text('2:00 / 8:00'), findsOneWidget);
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

    budgetsTest('shows today progress: yellow while in progress', (
      tester,
      storage,
    ) async {
      await addGoal(tester, 'work', '8');
      final brightness = Theme.of(tester.element(find.byType(BudgetsPage)))
          .brightness;
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('daily-goal-bar-work')),
      );
      expect(bar.value, closeTo(0.25, 0.001));
      expect(bar.color, goalBarColor(achieved: false, brightness: brightness));
      expect(find.byKey(const Key('daily-goal-achieved-work')), findsNothing);
    });

    budgetsTest('shows today progress: green and checked once reached', (
      tester,
      storage,
    ) async {
      await addGoal(tester, 'work', '1.5');
      final brightness = Theme.of(tester.element(find.byType(BudgetsPage)))
          .brightness;
      expect(find.text('2:00 / 1:30'), findsOneWidget);
      expect(find.byKey(const Key('daily-goal-achieved-work')), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('daily-goal-bar-work')),
      );
      expect(bar.value, 1);
      expect(bar.color, goalBarColor(achieved: true, brightness: brightness));
    });

    budgetsTest('a project with no time today shows 0:00', (
      tester,
      storage,
    ) async {
      await addGoal(tester, 'personal', '1');
      expect(find.text('0:00 / 1:00'), findsOneWidget);
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
      await tester.enterText(find.byKey(const Key('budget-account')), 'a  b');
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

  group('pace chart', () {
    const files = {
      '2026-10.timeclock': _data,
      'budget.journal':
          '~ weekly\n    (work)    10h\n\n~ daily\n    (work)    8h\n',
    };

    budgetsTest('is hidden until the pace is shown', (tester, _) async {
      const toggle = Key('goal-pace-toggle-Every week-work');
      expect(find.byKey(const Key('goal-pace-Every week-work')), findsNothing);

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('goal-pace-lines-Every week-work')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('goal-pace-bars-Every week-work')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-pace-Every week-work')), findsNothing);
    }, files: files);

    budgetsTest('daily goals have no pace', (tester, _) async {
      expect(
        find.byKey(const Key('goal-pace-toggle-Every day-work')),
        findsNothing,
      );
    }, files: files);
  });
}
