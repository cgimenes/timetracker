import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/budgets/budgets_page.dart';
import 'package:timetracker/ui/calendar/calendar_page.dart';
import 'package:timetracker/ui/entries/entries_page.dart';
import 'package:timetracker/ui/metrics/metrics_page.dart';
import 'package:timetracker/ui/settings_page.dart';
import 'package:timetracker/ui/theme.dart';
import 'package:timetracker/ui/track/track_page.dart';

import '../support/memory_storage.dart';

final now = DateTime(2026, 10, 30, 15);

const _data =
    'i 2026-10-29 09:00:00 personal:read\n'
    'o 2026-10-29 10:00:00 personal:read\n'
    'i 2026-10-30 14:00:00 work:acme:meet\n';

/// Mounts [page] with the app theme on a phone-sized screen.
void alignTest(
  String name,
  Widget page,
  Future<void> Function(WidgetTester tester) body, {
  Map<String, Object> prefs = const {},
  Map<String, String> files = const {
    '2026-10.timeclock': _data,
    'budget.journal':
        '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    40h\n',
  },
}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'budgetsEnabled': true, ...prefs});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          initialTreeUriProvider.overrideWithValue(
            'content://com.android.externalstorage.documents/tree/primary%3Atime',
          ),
          timeclockStorageProvider.overrideWithValue(MemoryStorage(files)),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(theme: appTheme(), home: page),
      ),
    );
    await tester.pumpAndSettle();
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}

/// Distance from the right edge of [container] to the right edge of what
/// the eye sees of [child].
double rightInset(WidgetTester tester, Finder child, Finder container) =>
    tester.getRect(container.first).right - tester.getRect(child.first).right;

/// Distance from the left edge of [container] to [child].
double leftInset(WidgetTester tester, Finder child, Finder container) =>
    tester.getRect(child.first).left - tester.getRect(container.first).left;

/// Content is 16 dp from the edge on the left; the right side must match.
const _edge = 16.0;

Matcher get _aligned => closeTo(_edge, 0.5);

Finder icon(IconData data, Finder inside) =>
    find.descendant(of: inside, matching: find.byIcon(data));

Finder tileOf(Finder inside) =>
    find.ancestor(of: inside, matching: find.byType(ListTile)).first;

void main() {
  group('right aligned controls sit as far from the edge as the text', () {
    alignTest('Entries: menu button', const EntriesPage(), (tester) async {
      final tile = find.widgetWithText(ListTile, 'personal:read');
      expect(leftInset(tester, find.text('personal:read'), tile), _aligned);
      expect(rightInset(tester, icon(Icons.more_vert, tile), tile), _aligned);
    });

    alignTest(
      'Entries: still aligned with the actions open',
      const EntriesPage(),
      (tester) async {
        final tile = find.widgetWithText(ListTile, 'personal:read');
        await tester.tap(
          find.descendant(of: tile, matching: find.byTooltip('Actions')),
        );
        await tester.pumpAndSettle();
        expect(rightInset(tester, icon(Icons.more_vert, tile), tile), _aligned);
      },
    );

    alignTest('Track: quick start play button', const TrackPage(), (
      tester,
    ) async {
      final play = find.byKey(const Key('quick-personal:read'));
      final tile = tileOf(play);
      // A filled button shows a 40 dp circle; its edge is what the eye sees.
      final circleRight =
          tester.getRect(icon(Icons.play_arrow, play)).right + 8;
      expect(tester.getRect(tile).right - circleRight, _aligned);
      expect(
        leftInset(tester, find.text('personal:read').first, tile),
        _aligned,
      );
    });

    alignTest('Track: menu button of a running entry', const TrackPage(), (
      tester,
    ) async {
      final menu = find.byKey(const Key('stop-menu'));
      final tile = tileOf(menu);
      expect(rightInset(tester, icon(Icons.more_vert, menu), tile), _aligned);
    });

    alignTest('Metrics: level plus button', const MetricsPage(), (
      tester,
    ) async {
      final plus = find.byKey(const Key('level-plus'));
      expect(rightInset(tester, icon(Icons.add, plus), tileOf(plus)), _aligned);
    });

    alignTest('Goals: delete button', const BudgetsPage(), (tester) async {
      final tile = find.byKey(const Key('budget-2026-10-work'));
      expect(
        rightInset(tester, icon(Icons.delete_outline, tile), tile),
        _aligned,
      );
    });

    alignTest('Settings: daily goal delete button', const SettingsPage(), (
      tester,
    ) async {
      final tile = find.byKey(const Key('daily-goal-work'));
      await tester.ensureVisible(tile);
      expect(
        rightInset(tester, icon(Icons.delete_outline, tile), tile),
        _aligned,
      );
      expect(leftInset(tester, find.text('work'), tile), _aligned);
    }, prefs: const {'dailyGoals': '{"work":28800}'});

    alignTest(
      'Settings: the Change button and the week start control',
      const SettingsPage(),
      (tester) async {
        final folder = find.widgetWithText(ListTile, 'Files directory');
        expect(
          rightInset(
            tester,
            find.descendant(of: folder, matching: find.text('Change')),
            folder,
          ),
          _aligned,
        );
        final week = find.byKey(const Key('week-start'));
        await tester.ensureVisible(week);
        expect(rightInset(tester, week, tileOf(week)), _aligned);
      },
    );

    alignTest(
      'Settings: switches line up with the other controls',
      const SettingsPage(),
      (tester) async {
        final tile = find.byKey(const Key('budgets-enabled'));
        await tester.ensureVisible(tile);
        final switchRight = tester
            .getRect(find.descendant(of: tile, matching: find.byType(Switch)))
            .right;
        final week = find.byKey(const Key('week-start'));
        // The switch is drawn inside its own box, 8 dp short of its edge at
        // most: it must not be further in than the segmented control.
        expect(
          tester.getRect(tile).right - switchRight,
          lessThanOrEqualTo(_edge + 8),
        );
        expect(tester.getRect(week).right, greaterThanOrEqualTo(switchRight));
      },
    );

    alignTest('Calendar: day bar buttons', const CalendarPage(), (
      tester,
    ) async {
      final today = find.descendant(
        of: find.byKey(const Key('cal-today')),
        matching: find.text('Today'),
      );
      expect(800 - tester.getRect(today).right, _aligned);
      final prev = icon(Icons.chevron_left, find.byKey(const Key('cal-prev')));
      expect(tester.getRect(prev).left, _aligned);
    });
  });
}
