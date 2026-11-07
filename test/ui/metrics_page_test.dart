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
      expect(find.text('No time tracked'), findsNWidgets(3));
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
      expect(find.text('work'), findsNWidgets(3));
      expect(
        find.text('personal'),
        findsNWidgets(2),
      ); // this week and this month
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
      expect(find.text('work:acme'), findsNWidgets(3));
      expect(find.text('work:globex'), findsNWidgets(3));

      await tester.tap(find.byKey(const Key('level-plus')));
      await tester.pump();
      expect(find.text('work:acme:dev'), findsNWidgets(3));
      expect(find.text('work:acme:meet'), findsNWidgets(3));

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
  });
}
