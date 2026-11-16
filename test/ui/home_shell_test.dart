import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/home_shell.dart';

import '../support/memory_storage.dart';

final now = DateTime(2026, 10, 30, 15);

/// Runs [body] with the app shell on a screen of [size].
void shellTest(
  String name,
  Future<void> Function(WidgetTester tester, ProviderContainer c) body, {
  Size size = const Size(400, 800),
  Map<String, Object> prefs = const {},
}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
          timeclockStorageProvider.overrideWithValue(MemoryStorage()),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeShell)));
    try {
      await body(tester, c);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}

void main() {
  shellTest('tabs at the bottom, a title bar with the screen name and a cog', (
    tester,
    _,
  ) async {
    expect(find.byKey(const Key('tab-bar')), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsNothing);
    expect(find.byKey(const Key('side-rail')), findsNothing);
    final bar = find.byKey(const Key('tab-bar'));
    for (final label in ['Track', 'Entries', 'Calendar', 'Metrics', 'Goals']) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: bar, matching: find.text('Settings')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Track')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings')), findsOneWidget);
  });

  shellTest('selecting a tab switches the screen and the title', (
    tester,
    _,
  ) async {
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Metrics')),
      findsOneWidget,
    );
  });

  shellTest('the cog opens Settings and back returns', (tester, _) async {
    await tester.tap(find.byKey(const Key('settings')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar).last,
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tab-bar')).hitTestable(), findsOneWidget);
  });

  shellTest('the same on a wide screen', (tester, _) async {
    expect(find.byKey(const Key('tab-bar')), findsOneWidget);
    expect(find.byKey(const Key('side-rail')), findsNothing);
  }, size: const Size(900, 600));
}
