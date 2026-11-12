import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/core/file_naming.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/settings/app_settings.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/folder_name.dart';
import 'package:timetracker/ui/settings_page.dart';

/// Runs [body] with the Settings page mounted. The widget tree owns the
/// container and is unmounted at the end, which stops the clock timer.
void settingsTest(
  String name,
  Future<void> Function(WidgetTester tester, ProviderContainer container)
  body, {
  String? treeUri,
  Map<String, Object> prefs = const {},
}) {
  testWidgets(name, (tester) async {
    // Phone-sized screen, so the whole list is on screen.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PackageInfo.setMockInitialValues(
      appName: 'timetracker',
      packageName: 'dev.cgimenes.timetracker',
      version: '1.3.0',
      buildNumber: '4',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          initialTreeUriProvider.overrideWithValue(treeUri),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 30, 15)),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    try {
      await body(tester, container);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Finder segment(String label) => find.descendant(
  of: find.byKey(const Key('project-split')),
  matching: find.text(label),
);

void main() {
  group('friendlyFolderName', () {
    test('internal storage', () {
      expect(
        friendlyFolderName(
          'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2Ftime',
        ),
        'Documents/time',
      );
      expect(
        friendlyFolderName(
          'content://com.android.externalstorage.documents/tree/primary%3A',
        ),
        'Internal storage',
      );
    });

    test('other volumes keep their id', () {
      expect(
        friendlyFolderName(
          'content://com.android.externalstorage.documents/tree/1234-ABCD%3Atime',
        ),
        '1234-ABCD: time',
      );
    });

    test('anything else is shown as it is', () {
      expect(friendlyFolderName('content://x/other'), 'content://x/other');
      expect(friendlyFolderName('not a uri %%'), isNotEmpty);
    });
  });

  group('SettingsPage', () {
    settingsTest('shows defaults and an example file name', (tester, c) async {
      expect(find.text('Not chosen yet'), findsOneWidget);
      expect(find.text('Choose'), findsOneWidget);
      expect(find.text('Example: 2026-10.timeclock'), findsOneWidget);
    });

    settingsTest(
      'shows the chosen folder',
      (tester, c) async {
        expect(find.text('Documents/time'), findsOneWidget);
        expect(find.text('Change'), findsOneWidget);
      },
      treeUri: 'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2Ftime',
    );

    settingsTest('changing the split updates the template and the example', (
      tester,
      c,
    ) async {
      await tester.tap(find.text('Day'));
      await tester.pump();

      expect(c.read(settingsProvider).split.name, 'day');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('template')))
            .controller!
            .text,
        '{yyyy}-{MM}-{dd}.timeclock',
      );
      expect(find.text('Example: 2026-10-30.timeclock'), findsOneWidget);
    });

    settingsTest(
      'a template that cannot tell periods apart shows an error and is not saved',
      (tester, c) async {
        await tester.enterText(
          find.byKey(const Key('template')),
          'all.timeclock',
        );
        await tester.pump();

        expect(find.textContaining('must contain {yyyy}'), findsOneWidget);
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{yyyy}-{MM}.timeclock',
        );
      },
    );

    settingsTest('a valid custom template is saved', (tester, c) async {
      await tester.enterText(
        find.byKey(const Key('template')),
        'hours-{MM}-{yyyy}.timeclock',
      );
      await tester.pump();

      expect(
        c.read(settingsProvider).fileNameTemplate,
        'hours-{MM}-{yyyy}.timeclock',
      );
      expect(find.text('Example: hours-10-2026.timeclock'), findsOneWidget);
    });

    settingsTest('projects setting changes the file name and example', (
      tester,
      c,
    ) async {
      expect(find.text('Example: 2026-10.timeclock'), findsOneWidget);

      await tester.tap(segment('File name'));
      await tester.pump();

      expect(c.read(settingsProvider).splitByProject, isTrue);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('template')))
            .controller!
            .text,
        '{project}-{yyyy}-{MM}.timeclock',
      );
      expect(find.text('Example: work-2026-10.timeclock'), findsOneWidget);

      await tester.tap(segment('Together'));
      await tester.pump();
      expect(find.text('Example: 2026-10.timeclock'), findsOneWidget);
    });

    settingsTest(
      'folders keep the template and show the folder in the example',
      (tester, c) async {
        await tester.tap(segment('Folders'));
        await tester.pump();

        expect(c.read(settingsProvider).projects, ProjectSplit.folder);
        expect(c.read(settingsProvider).fileSettings.projectFolders, isTrue);
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{yyyy}-{MM}.timeclock',
        );
        expect(find.text('Example: work/2026-10.timeclock'), findsOneWidget);
      },
    );

    settingsTest(
      'with projects in the file name, a name without {project} is refused',
      (tester, c) async {
        await tester.tap(segment('File name'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('template')),
          '{yyyy}-{MM}.timeclock',
        );
        await tester.pump();

        expect(find.textContaining('must contain {project}'), findsOneWidget);
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{project}-{yyyy}-{MM}.timeclock',
        );
      },
    );

    settingsTest('has no header and no metrics level any more', (
      tester,
      c,
    ) async {
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('level-plus')), findsNothing);
    });

    settingsTest('week start', (tester, c) async {
      await tester.tap(find.text('Sun'));
      await tester.pump();
      expect(c.read(settingsProvider).weekStart.name, 'sunday');
    });

    settingsTest('shows a small version number at the end', (tester, c) async {
      await tester.pumpAndSettle();
      final version = find.byKey(const Key('version'));
      await tester.ensureVisible(version);
      expect(tester.widget<Text>(version).data, 'v1.3.0');
      // Last thing in the list: below the week start control.
      expect(
        tester.getTopLeft(version).dy,
        greaterThan(tester.getTopLeft(find.byKey(const Key('week-start'))).dy),
      );
    });

    settingsTest('has no Goals switch, the Goals screen is always there', (
      tester,
      c,
    ) async {
      expect(find.byKey(const Key('budgets-enabled')), findsNothing);
    });

    group('daily goals', () {
      Future<void> addGoal(
        WidgetTester tester,
        String project,
        String hours,
      ) async {
        await tester.ensureVisible(find.byKey(const Key('add-daily-goal')));
        await tester.tap(find.byKey(const Key('add-daily-goal')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('budget-project')),
          project,
        );
        await tester.enterText(find.byKey(const Key('budget-hours')), hours);
        await tester.pump();
        await tester.tap(find.byKey(const Key('budget-save')));
        await tester.pumpAndSettle();
      }

      settingsTest('starts empty', (tester, c) async {
        await tester.ensureVisible(find.byKey(const Key('add-daily-goal')));
        expect(find.text('No daily goals'), findsOneWidget);
        expect(c.read(settingsProvider).dailyGoals, isEmpty);
      });

      settingsTest('add saves the goal in the settings', (tester, c) async {
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

      settingsTest('the dialog does not ask for a period', (tester, c) async {
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

      settingsTest('goals are per project', (tester, c) async {
        await addGoal(tester, 'work', '6');
        await addGoal(tester, 'personal', '1.5');
        expect(c.read(settingsProvider).dailyGoals, {
          'work': const Duration(hours: 6),
          'personal': const Duration(hours: 1, minutes: 30),
        });
        expect(find.byKey(const Key('daily-goal-work')), findsOneWidget);
        expect(find.byKey(const Key('daily-goal-personal')), findsOneWidget);
      });

      settingsTest('edit changes the hours, remove asks first', (
        tester,
        c,
      ) async {
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

      settingsTest('a bad project or hours cannot be saved', (tester, c) async {
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

      settingsTest(
        'saved goals are read back, junk is ignored',
        (tester, c) async {
          expect(c.read(settingsProvider).dailyGoals, {
            'work': const Duration(hours: 2),
          });
        },
        prefs: const {
          'dailyGoals': '{"work":7200,"bad":"x","zero":0,"neg":-5}',
        },
      );

      settingsTest('unreadable saved goals mean none', (tester, c) async {
        expect(c.read(settingsProvider).dailyGoals, isEmpty);
      }, prefs: const {'dailyGoals': 'not json'});
    });
  });
}
