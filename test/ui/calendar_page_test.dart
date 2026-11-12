import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/settings/app_settings.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/ui/calendar/calendar_page.dart';

import '../support/memory_storage.dart';

// Friday 2026-10-30, 15:00.
final now = DateTime(2026, 10, 30, 15);

const _data =
    'i 2026-10-29 09:00:00 personal:read\n'
    'o 2026-10-29 10:00:00 personal:read\n'
    'i 2026-10-30 09:00:00 work:acme:dev\n'
    'o 2026-10-30 11:00:00 work:acme:dev\n'
    'i 2026-10-30 10:00:00 work:globex:dev\n'
    'o 2026-10-30 12:00:00 work:globex:dev\n'
    'i 2026-10-30 14:00:00 work:acme:meet\n';

void calendarTest(
  String name,
  Future<void> Function(
    WidgetTester tester,
    ProviderContainer c,
    MemoryStorage storage,
  )
  body, {
  Map<String, String> files = const {'2026-10.timeclock': _data},
  Map<String, Object> prefs = const {},
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
        child: const MaterialApp(home: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(CalendarPage)),
    );
    try {
      await body(tester, c, storage);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Finder block(String account) =>
    find.descendant(of: find.byType(Positioned), matching: find.text(account));

void main() {
  group('CalendarPage', () {
    calendarTest('shows today with its entries and the now line', (
      tester,
      noC,
      noS,
    ) async {
      expect(find.text('Fri 2026-10-30'), findsOneWidget);
      expect(block('work:acme:dev'), findsOneWidget);
      expect(block('work:globex:dev'), findsOneWidget);
      expect(block('work:acme:meet'), findsOneWidget);
      expect(block('personal:read'), findsNothing);
      expect(find.byKey(const Key('cal-now')), findsOneWidget);
    });

    calendarTest(
      'overlapping entries sit side by side, the others full width',
      (tester, _, noS) async {
        final dev = tester.getRect(
          find
              .ancestor(
                of: block('work:acme:dev'),
                matching: find.byType(Material),
              )
              .first,
        );
        final globex = tester.getRect(
          find
              .ancestor(
                of: block('work:globex:dev'),
                matching: find.byType(Material),
              )
              .first,
        );
        final meet = tester.getRect(
          find
              .ancestor(
                of: block('work:acme:meet'),
                matching: find.byType(Material),
              )
              .first,
        );
        // 09-11 and 10-12 overlap: same width, one beside the other.
        expect(dev.width, closeTo(globex.width, 0.5));
        expect(globex.left, greaterThan(dev.left));
        expect(dev.top, lessThan(globex.top));
        // 14-15 is alone: twice as wide.
        expect(meet.width, greaterThan(dev.width * 1.8));
      },
    );

    calendarTest('blocks sit at their time', (tester, _, noS) async {
      Rect rect(String a) => tester.getRect(
        find.ancestor(of: block(a), matching: find.byType(Material)).first,
      );
      final dev = rect('work:acme:dev');
      final globex = rect('work:globex:dev');
      // One hour is 56 px: globex starts an hour after dev, both last 2 h.
      expect(globex.top - dev.top, closeTo(56, 0.5));
      expect(dev.height, closeTo(112, 0.5));
    });

    calendarTest('previous day, next day and Today', (tester, _, noS) async {
      expect(
        tester.widget<TextButton>(find.byKey(const Key('cal-today'))).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(find.byKey(const Key('cal-next'))).onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('cal-prev')));
      await tester.pumpAndSettle();
      expect(find.text('Thu 2026-10-29'), findsOneWidget);
      expect(block('personal:read'), findsOneWidget);
      expect(block('work:acme:dev'), findsNothing);
      expect(find.byKey(const Key('cal-now')), findsNothing);

      await tester.tap(find.byKey(const Key('cal-next')));
      await tester.pumpAndSettle();
      expect(find.text('Fri 2026-10-30'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cal-prev')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cal-today')));
      await tester.pumpAndSettle();
      expect(find.text('Fri 2026-10-30'), findsOneWidget);
    });

    calendarTest('the date opens a picker to jump to a day', (
      tester,
      c,
      noS,
    ) async {
      await tester.tap(find.byKey(const Key('cal-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('29'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Thu 2026-10-29'), findsOneWidget);
      expect(block('personal:read'), findsOneWidget);
    });

    calendarTest('an empty day says so', (tester, _, noS) async {
      await tester.tap(find.byKey(const Key('cal-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('27'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('No entries'), findsOneWidget);
    });

    calendarTest('the legend and colors follow the level', (
      tester,
      c,
      noS,
    ) async {
      Finder legend(String name) => find.descendant(
        of: find.byKey(const Key('cal-legend')),
        matching: find.text(name),
      );
      // Level 1: every entry of the day is "work".
      expect(legend('work'), findsOneWidget);
      expect(legend('work:acme'), findsNothing);

      Color colorOf(String account) {
        final material = tester.widget<Material>(
          find
              .ancestor(of: block(account), matching: find.byType(Material))
              .first,
        );
        return material.color!;
      }

      expect(colorOf('work:acme:dev'), colorOf('work:globex:dev'));

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cal-level')),
          matching: find.text('Level 2'),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).calendarLevel, 2);
      expect(c.read(sharedPreferencesProvider).getInt('calendarLevel'), 2);
      expect(legend('work:acme'), findsOneWidget);
      expect(legend('work:globex'), findsOneWidget);
      expect(colorOf('work:acme:dev'), isNot(colorOf('work:globex:dev')));
      // Same group, same color: dev and meet are both work:acme.
      expect(colorOf('work:acme:dev'), colorOf('work:acme:meet'));
    });

    calendarTest('level 3 gives every account of three levels its own color', (
      tester,
      c,
      storage,
    ) async {
      Finder legend(String name) => find.descendant(
        of: find.byKey(const Key('cal-legend')),
        matching: find.text(name),
      );
      Color colorOf(String account) {
        final material = tester.widget<Material>(
          find
              .ancestor(of: block(account), matching: find.byType(Material))
              .first,
        );
        return material.color!;
      }

      // Level 2: dev and meet are both work:acme, one color.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cal-level')),
          matching: find.text('Level 2'),
        ),
      );
      await tester.pumpAndSettle();
      expect(colorOf('work:acme:dev'), colorOf('work:acme:meet'));

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cal-level')),
          matching: find.text('Level 3'),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).calendarLevel, 3);
      expect(c.read(sharedPreferencesProvider).getInt('calendarLevel'), 3);
      expect(legend('work:acme:dev'), findsOneWidget);
      expect(legend('work:acme:meet'), findsOneWidget);
      expect(legend('work:globex:dev'), findsOneWidget);
      expect(colorOf('work:acme:dev'), isNot(colorOf('work:acme:meet')));
      expect(colorOf('work:acme:dev'), isNot(colorOf('work:globex:dev')));
    });

    calendarTest('level 3 is remembered', (tester, c, storage) async {
      expect(c.read(settingsProvider).calendarLevel, 3);
      expect(find.byKey(const Key('cal-legend')), findsOneWidget);
    }, prefs: const {'calendarLevel': 3});

    calendarTest('the level is remembered', (tester, c, noS) async {
      expect(c.read(settingsProvider).calendarLevel, 2);
      expect(find.byKey(const Key('cal-legend')), findsOneWidget);
    }, prefs: const {'calendarLevel': 2});

    calendarTest('tap a block: details and the three actions', (
      tester,
      _,
      storage,
    ) async {
      // personal:read is on the day before.
      await tester.tap(find.byKey(const Key('cal-prev')));
      await tester.pumpAndSettle();
      await tester.tap(block('personal:read'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cal-restart')), findsOneWidget);
      expect(find.byKey(const Key('cal-edit')), findsOneWidget);
      expect(find.byKey(const Key('cal-remove')), findsOneWidget);
      expect(find.textContaining('2026-10-29 09:00 to 10:00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cal-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Remove entry?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(
        storage.text('2026-10.timeclock'),
        _data.replaceAll(
          'i 2026-10-29 09:00:00 personal:read\n'
              'o 2026-10-29 10:00:00 personal:read\n',
          '',
        ),
      );
      expect(block('personal:read'), findsNothing);
    });

    calendarTest('Edit from a block opens the edit page', (
      tester,
      noC,
      noS,
    ) async {
      await tester.tap(block('work:acme:dev'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cal-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit entry'), findsOneWidget);
    });

    calendarTest('Start again from a block asks now or a time', (
      tester,
      _,
      storage,
    ) async {
      await tester.tap(block('work:acme:dev'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cal-restart')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('restart-now')));
      await tester.pumpAndSettle();
      expect(
        storage.text('2026-10.timeclock'),
        '${_data}i 2026-10-30 15:00:00 work:acme:dev\n',
      );
    });

    calendarTest('a running entry offers Edit and Cancel, not Start again', (
      tester,
      _,
      storage,
    ) async {
      await tester.tap(block('work:acme:meet'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cal-restart')), findsNothing);
      expect(find.text('Cancel entry'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cal-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Cancel entry?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancel-confirm')));
      await tester.pumpAndSettle();
      expect(
        storage.text('2026-10.timeclock'),
        _data.replaceAll('i 2026-10-30 14:00:00 work:acme:meet\n', ''),
      );
    });

    calendarTest(
      'asks for a folder when none is chosen',
      (tester, _, noS) async {},
      files: const {},
    );

    group('zoom', () {
      double hourHeight(ProviderContainer c) =>
          c.read(settingsProvider).calendarHourHeight;

      double blockHeight(WidgetTester tester, String account) => tester
          .getSize(
            find
                .ancestor(of: block(account), matching: find.byType(Material))
                .first,
          )
          .height;

      calendarTest('starts at 56 px per hour', (tester, c, storage) async {
        expect(hourHeight(c), 56);
        expect(blockHeight(tester, 'work:acme:dev'), closeTo(112, 0.5));
      });

      calendarTest('the buttons zoom in and out and the blocks follow', (
        tester,
        c,
        storage,
      ) async {
        await tester.tap(find.byKey(const Key('cal-zoom-in')));
        await tester.pumpAndSettle();
        expect(hourHeight(c), 70);
        expect(blockHeight(tester, 'work:acme:dev'), closeTo(140, 0.5));

        await tester.tap(find.byKey(const Key('cal-zoom-out')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cal-zoom-out')));
        await tester.pumpAndSettle();
        expect(hourHeight(c), closeTo(44.8, 0.01));
        expect(blockHeight(tester, 'work:acme:dev'), closeTo(89.6, 0.5));
      });

      calendarTest('zoom stops at the limits and the buttons turn off', (
        tester,
        c,
        storage,
      ) async {
        for (var i = 0; i < 12; i++) {
          await tester.tap(
            find.byKey(const Key('cal-zoom-out')),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();
        }
        expect(hourHeight(c), minHourHeight);
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const Key('cal-zoom-out')),
              )
              .onPressed,
          isNull,
        );

        for (var i = 0; i < 20; i++) {
          await tester.tap(
            find.byKey(const Key('cal-zoom-in')),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();
        }
        expect(hourHeight(c), maxHourHeight);
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const Key('cal-zoom-in')),
              )
              .onPressed,
          isNull,
        );
      });

      calendarTest('the zoom is saved', (tester, c, storage) async {
        await tester.tap(find.byKey(const Key('cal-zoom-in')));
        await tester.pumpAndSettle();
        expect(
          c.read(sharedPreferencesProvider).getDouble('calendarHourHeight'),
          70,
        );
      });

      calendarTest('a saved zoom is used, kept inside the limits', (
        tester,
        c,
        storage,
      ) async {
        expect(hourHeight(c), 100);
        expect(blockHeight(tester, 'work:acme:dev'), closeTo(200, 0.5));
      }, prefs: const {'calendarHourHeight': 100.0});

      calendarTest('a silly saved zoom is clamped', (tester, c, storage) async {
        expect(hourHeight(c), maxHourHeight);
      }, prefs: const {'calendarHourHeight': 9999.0});

      calendarTest('pinching with two fingers zooms', (
        tester,
        c,
        storage,
      ) async {
        final center = tester.getCenter(find.byType(SingleChildScrollView));
        final a = await tester.startGesture(
          center - const Offset(0, 30),
          pointer: 1,
        );
        final b = await tester.startGesture(
          center + const Offset(0, 30),
          pointer: 2,
        );
        for (var i = 0; i < 2; i++) {
          await a.moveBy(const Offset(0, -15));
          await b.moveBy(const Offset(0, 15));
          await tester.pump();
        }
        await a.up();
        await b.up();
        await tester.pumpAndSettle();
        final big = hourHeight(c);
        expect(big, greaterThan(56));
        expect(big, lessThan(maxHourHeight));

        final a2 = await tester.startGesture(
          center - const Offset(0, 60),
          pointer: 3,
        );
        final b2 = await tester.startGesture(
          center + const Offset(0, 60),
          pointer: 4,
        );
        for (var i = 0; i < 2; i++) {
          await a2.moveBy(const Offset(0, 15));
          await b2.moveBy(const Offset(0, -15));
          await tester.pump();
        }
        await a2.up();
        await b2.up();
        await tester.pumpAndSettle();
        expect(hourHeight(c), lessThan(big));
      });

      calendarTest('one finger still scrolls and does not zoom', (
        tester,
        c,
        storage,
      ) async {
        // A short screen, so the day does not fit and can scroll.
        tester.view.physicalSize = const Size(800, 700);
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final before = scroll.position.pixels;
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(before));
        expect(hourHeight(c), 56);
      });
    });
  });
}
