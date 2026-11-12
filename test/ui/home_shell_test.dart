import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/settings/app_settings.dart';
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
  group('narrow screen', () {
    shellTest('has a top bar with a menu button, no bottom bar or rail', (
      tester,
      _,
    ) async {
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const Key('side-rail')), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    });

    shellTest('the drawer lists the screens and switching closes it', (
      tester,
      _,
    ) async {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      final drawer = find.byKey(const Key('side-drawer'));
      for (final label in [
        'Track',
        'Entries',
        'Calendar',
        'Metrics',
        'Goals',
        'Settings',
      ]) {
        expect(
          find.descendant(of: drawer, matching: find.text(label)),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.descendant(of: drawer, matching: find.text('Metrics')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('side-drawer')), findsNothing);
      // The top bar names the screen.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Metrics'),
        ),
        findsOneWidget,
      );
    });
  });

  group('wide screen', () {
    const wide = Size(900, 600);

    shellTest('has a rail and no top bar, collapsed to icons', (
      tester,
      c,
    ) async {
      expect(find.byKey(const Key('side-rail')), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('side-drawer')), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('side-rail'))).width,
        lessThan(120),
      );
    }, size: wide);

    shellTest('the toggle expands and collapses it and remembers', (
      tester,
      c,
    ) async {
      final narrow = tester.getSize(find.byKey(const Key('side-rail'))).width;
      await tester.tap(find.byKey(const Key('side-toggle')));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).sideBarExpanded, isTrue);
      expect(
        c.read(sharedPreferencesProvider).getBool('sideBarExpanded'),
        isTrue,
      );
      expect(
        tester.getSize(find.byKey(const Key('side-rail'))).width,
        greaterThan(narrow),
      );
      expect(find.text('Entries'), findsOneWidget);

      await tester.tap(find.byKey(const Key('side-toggle')));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).sideBarExpanded, isFalse);
    }, size: wide);

    shellTest(
      'starts expanded when it was left expanded',
      (tester, c) async {
        expect(find.text('Entries'), findsOneWidget);
      },
      size: wide,
      prefs: const {'sideBarExpanded': true},
    );

    shellTest('selecting a destination switches the screen', (tester, c) async {
      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pumpAndSettle();
      expect(find.text('This week'), findsOneWidget);
    }, size: wide);
  });
}
