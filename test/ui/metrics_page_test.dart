import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/settings/app_settings.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/metrics/metrics_page.dart';

import '../support/memory_storage.dart';

// Friday 2026-10-30, 15:00.
final now = DateTime(2026, 10, 30, 15);

const _data =
    'i 2026-10-30 09:00:00 work:acme:dev\n'
    'o 2026-10-30 11:00:00 work:acme:dev\n'
    'i 2026-10-30 11:00:00 work:globex:dev\n'
    'o 2026-10-30 11:30:00 work:globex:dev\n'
    'i 2026-10-28 09:00:00 personal:read\n'
    'o 2026-10-28 10:00:00 personal:read\n'
    'i 2026-10-30 14:00:00 work:acme:meet\n';

/// Runs [body] with the Metrics page mounted on a phone-sized screen. The
/// widget tree owns the container and is unmounted at the end.
void metricsTest(
  String name,
  Future<void> Function(
    WidgetTester tester,
    ProviderContainer container,
    MemoryStorage storage,
  )
  body, {
  Map<String, String> files = const {'2026-10.timeclock': _data},
  bool withFolder = true,
  Map<String, Object> prefs = const {'budgetsEnabled': true},
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
            withFolder
                ? 'content://com.android.externalstorage.documents/tree/primary%3Atime'
                : null,
          ),
          timeclockStorageProvider.overrideWithValue(storage),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: MetricsPage()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MetricsPage)),
    );
    try {
      await body(tester, container, storage);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}

String total(WidgetTester tester, String period) =>
    tester.widget<Text>(find.byKey(Key('total-$period'))).data!;

void main() {
  group('MetricsPage', () {
    metricsTest('asks for a folder when none is chosen', (
      tester,
      c,
      storage,
    ) async {
      expect(find.byKey(const Key('choose-folder')), findsOneWidget);
    }, withFolder: false);

    metricsTest('empty directory', (tester, c, storage) async {
      // Three period cards and the chart.
      expect(find.text('No time tracked'), findsNWidgets(4));
    }, files: const {});

    metricsTest('has no header', (tester, c, storage) async {
      expect(find.byType(AppBar), findsNothing);
    });

    metricsTest('totals for today, this week and this month', (
      tester,
      c,
      storage,
    ) async {
      // Today: dev 2:00 + globex 0:30 + meet running 1:00 = 3:30.
      expect(total(tester, 'today'), '3:30');
      // The week (Mon 26 to Sun 1) also has Wednesday's reading: 4:30.
      expect(total(tester, 'week'), '4:30');
      expect(total(tester, 'month'), '4:30');
    });

    metricsTest('groups at level 1 by default, longest first', (
      tester,
      c,
      storage,
    ) async {
      expect(find.byKey(const Key('level')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('level'))).data, '1');
      // Three period cards and the chart legend.
      expect(find.text('work'), findsNWidgets(4));
      expect(
        find.text('personal'),
        findsNWidgets(3),
      ); // this week, this month and the chart legend
    });

    metricsTest('changing the level regroups the totals', (
      tester,
      c,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('level-plus')));
      await tester.pump();
      expect(c.read(settingsProvider).metricsLevel, 2);
      expect(find.textContaining('is work:acme.'), findsOneWidget);
      expect(find.text('work:acme'), findsNWidgets(4));
      expect(find.text('work:globex'), findsNWidgets(4));

      await tester.tap(find.byKey(const Key('level-plus')));
      await tester.pump();
      expect(find.text('work:acme:dev'), findsNWidgets(4));
      expect(find.text('work:acme:meet'), findsNWidgets(4));

      // The totals do not change, only the grouping.
      expect(total(tester, 'today'), '3:30');
    });

    metricsTest('the level never goes below 1', (tester, c, storage) async {
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('level-minus')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('level-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('level-minus')));
      await tester.pump();
      expect(c.read(settingsProvider).metricsLevel, 1);
    });

    metricsTest('the level is remembered', (tester, c, storage) async {
      await tester.tap(find.byKey(const Key('level-plus')));
      await tester.pump();
      expect(c.read(sharedPreferencesProvider).getInt('metricsLevel'), 2);
    });

    metricsTest(
      'shows budgets with used and allowed time, over budget in error color',
      (tester, container, storage) async {
        // Work today: 2:00 + 0:30 + 1:00 running.
        final daily = find.byKey(const Key('budget-today-work'));
        expect(daily, findsOneWidget);
        expect(
          find.descendant(of: daily, matching: find.text('3:30 / 3:00')),
          findsOneWidget,
        );
        final over = tester.widget<Text>(
          find.descendant(of: daily, matching: find.text('3:30 / 3:00')),
        );
        final scheme = Theme.of(tester.element(daily)).colorScheme;
        expect(over.style?.color, scheme.error);

        final monthly = find.byKey(const Key('budget-month-work'));
        expect(
          find.descendant(of: monthly, matching: find.text('3:30 / 40:00')),
          findsOneWidget,
        );
        // No weekly budget: nothing for the week.
        expect(find.byKey(const Key('budget-week-work')), findsNothing);
      },
      files: const {
        '2026-10.timeclock': _data,
        'budget.journal':
            '~ daily\n    (work)    3h\n\n~ monthly\n    (work)    40h\n',
      },
    );

    metricsTest('without a budget file there is no Budgets section', (
      tester,
      container,
      storage,
    ) async {
      expect(find.text('Budgets'), findsNothing);
    });

    metricsTest(
      'a dated budget counts only its own window, other months are ignored',
      (tester, container, storage) async {
        // October window: all of the month's work, 3:30.
        final monthly = find.byKey(const Key('budget-month-work'));
        expect(
          find.descendant(of: monthly, matching: find.text('3:30 / 20:00')),
          findsOneWidget,
        );
        // A September budget is not for this month.
        expect(find.text('0:00 / 99:00'), findsNothing);
      },
      files: const {
        '2026-10.timeclock': _data,
        'budget.journal':
            '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    20h\n\n'
            '~ monthly from 2026-09-01 to 2026-10-01\n    (work)    99h\n',
      },
    );

    metricsTest(
      'budgets are hidden until enabled in Settings',
      (tester, container, storage) async {
        expect(find.text('Budgets'), findsNothing);
      },
      files: const {
        '2026-10.timeclock': _data,
        'budget.journal': '~ monthly\n    (work)    40h\n',
      },
      prefs: const {},
    );

    group('chart', () {
      BarChartData chart(WidgetTester tester) =>
          tester.widget<BarChart>(find.byKey(const Key('chart'))).data;

      metricsTest('shows days by default, stacked by project', (
        tester,
        container,
        storage,
      ) async {
        expect(find.byKey(const Key('chart-grouping')), findsOneWidget);
        final groups = chart(tester).barGroups;
        expect(groups, hasLength(14));
        // Today: work 3:30 (2:00 + 0:30 + 1:00 running).
        final today = groups.last.barRods.single;
        expect(today.toY, closeTo(3.5, 0.001));
        expect(today.rodStackItems, hasLength(1));
        // Oct 28: personal 1:00.
        final oct28 = groups[11].barRods.single;
        expect(oct28.toY, closeTo(1, 0.001));
        // Legend: one entry per project.
        final legend = find.byKey(const Key('chart-legend'));
        expect(
          find.descendant(of: legend, matching: find.text('work')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: legend, matching: find.text('personal')),
          findsOneWidget,
        );
      });

      metricsTest('the selector switches to weeks and months', (
        tester,
        container,
        storage,
      ) async {
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('chart-grouping')),
            matching: find.text('Week'),
          ),
        );
        await tester.pumpAndSettle();
        expect(chart(tester).barGroups, hasLength(12));
        // This week (Mon 26): work 3:30; the earlier personal hour is Wed 28.
        expect(
          chart(tester).barGroups.last.barRods.single.toY,
          closeTo(4.5, 0.001),
        );

        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('chart-grouping')),
            matching: find.text('Month'),
          ),
        );
        await tester.pumpAndSettle();
        expect(chart(tester).barGroups, hasLength(12));
        expect(
          chart(tester).barGroups.last.barRods.single.toY,
          closeTo(4.5, 0.001),
        );
      });

      metricsTest('follows the Metrics level', (
        tester,
        container,
        storage,
      ) async {
        await tester.tap(find.byKey(const Key('level-plus')));
        await tester.pumpAndSettle();
        final today = chart(tester).barGroups.last.barRods.single;
        // work:acme (3:00) and work:globex (0:30).
        expect(today.rodStackItems, hasLength(2));
        expect(
          find.descendant(
            of: find.byKey(const Key('chart-legend')),
            matching: find.text('work:acme'),
          ),
          findsOneWidget,
        );
      });

      metricsTest('without time tracked it says so', (
        tester,
        container,
        storage,
      ) async {
        expect(find.byKey(const Key('chart')), findsNothing);
        expect(find.text('No time tracked'), findsWidgets);
      }, files: const {});
    });
  });
}
