import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/data/timeclock_storage.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/entries/entries_page.dart';
import 'package:timetracker/ui/metrics/metrics_page.dart';
import 'package:timetracker/ui/track/track_page.dart';

import '../support/memory_storage.dart';

/// A directory that cannot be read until [failing] is set to false, like a
/// folder that was moved and then put back.
class FlakyStorage extends MemoryStorage {
  FlakyStorage() : super({'2026-10.timeclock': 'i 2026-10-30 14:00:00 a\n'});

  bool failing = true;

  @override
  Future<List<StoredFile>> list() async {
    if (failing) throw StateError('folder is gone');
    return super.list();
  }
}

void loadErrorTest(
  String name,
  Future<void> Function(WidgetTester tester, FlakyStorage storage) body,
  Widget page,
) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final storage = FlakyStorage();
    SharedPreferences.setMockInitialValues({});
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
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 30, 15)),
        ],
        child: MaterialApp(home: page),
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

void main() {
  group('when the files cannot be read', () {
    loadErrorTest('Track explains it and offers both ways out', (
      tester,
      storage,
    ) async {
      expect(find.byKey(const Key('load-error')), findsOneWidget);
      expect(find.text('Could not read the files'), findsOneWidget);
      expect(find.textContaining('folder is gone'), findsOneWidget);
      expect(find.byKey(const Key('retry')), findsOneWidget);
      expect(find.byKey(const Key('pick-another')), findsOneWidget);
      expect(find.byKey(const Key('start')), findsNothing);
    }, const TrackPage());

    loadErrorTest('Try again recovers once the folder is back', (
      tester,
      storage,
    ) async {
      storage.failing = false;
      await tester.tap(find.byKey(const Key('retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('load-error')), findsNothing);
      expect(find.byKey(const Key('start')), findsOneWidget);
      expect(find.text('a'), findsWidgets); // the running entry
    }, const TrackPage());

    loadErrorTest('Try again keeps showing the error while it still fails', (
      tester,
      storage,
    ) async {
      await tester.tap(find.byKey(const Key('retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('load-error')), findsOneWidget);
    }, const TrackPage());

    loadErrorTest('Entries shows the same card', (tester, storage) async {
      expect(find.byKey(const Key('load-error')), findsOneWidget);
      expect(find.byKey(const Key('retry')), findsOneWidget);
    }, const EntriesPage());

    loadErrorTest('Metrics shows the same card', (tester, storage) async {
      expect(find.byKey(const Key('load-error')), findsOneWidget);
      storage.failing = false;
      await tester.tap(find.byKey(const Key('retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('load-error')), findsNothing);
      expect(find.byKey(const Key('total-today')), findsOneWidget);
    }, const MetricsPage());
  });
}
