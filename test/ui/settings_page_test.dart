import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    settingsTest('split by project switch changes the file name and example', (
      tester,
      c,
    ) async {
      expect(find.text('Example: 2026-10.timeclock'), findsOneWidget);

      await tester.tap(find.byKey(const Key('split-by-project')));
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

      await tester.tap(find.byKey(const Key('split-by-project')));
      await tester.pump();
      expect(find.text('Example: 2026-10.timeclock'), findsOneWidget);
    });

    settingsTest(
      'with split by project on, a name without {project} is refused',
      (tester, c) async {
        await tester.tap(find.byKey(const Key('split-by-project')));
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
  });
}
