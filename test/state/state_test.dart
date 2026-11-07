import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/core/file_naming.dart';
import 'package:timetracker/core/metrics.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/data/timeclock_repository.dart';
import 'package:timetracker/data/timeclock_storage.dart';
import 'package:timetracker/settings/app_settings.dart';
import 'package:timetracker/state/clock.dart';
import 'package:timetracker/state/derived.dart';
import 'package:timetracker/state/entries.dart';

import '../support/memory_storage.dart';

// Friday 2026-10-30, 15:00.
final now = DateTime(2026, 10, 30, 15);
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);

Future<ProviderContainer> makeContainer(
  MemoryStorage storage, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      timeclockStorageProvider.overrideWithValue(storage),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(container.dispose);
  // Let the first load finish.
  await container.read(entriesProvider.future);
  return container;
}

/// Entries that have a clock-out, newest first.
List<StoredEntry> finished(ProviderContainer c) => c
    .read(entriesProvider)
    .requireValue
    .entries
    .where((e) => !e.entry.isRunning)
    .toList();

void main() {
  group('settings', () {
    test('defaults', () async {
      final c = await makeContainer(MemoryStorage());
      final s = c.read(settingsProvider);
      expect(s.split, SplitMethod.month);
      expect(s.fileNameTemplate, '{yyyy}-{MM}.timeclock');
      expect(s.metricsLevel, 1);
      expect(s.weekStart, WeekStart.monday);
    });

    test('are saved and restored', () async {
      final storage = MemoryStorage();
      final first = await makeContainer(storage);
      final settings = first.read(settingsProvider.notifier);
      await settings.setSplit(SplitMethod.week);
      expect(await settings.setMetricsLevel(3), isNull);
      await settings.setWeekStart(WeekStart.sunday);
      expect(
        await settings.setFileNameTemplate('w-{yyyy}-{ww}.timeclock'),
        isNull,
      );

      final saved = first.read(sharedPreferencesProvider);
      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(saved)],
      );
      addTearDown(second.dispose);
      final s = second.read(settingsProvider);
      expect(s.split, SplitMethod.week);
      expect(s.metricsLevel, 3);
      expect(s.weekStart, WeekStart.sunday);
      expect(s.fileNameTemplate, 'w-{yyyy}-{ww}.timeclock');
    });

    test('an unusable stored template falls back to the default', () async {
      final c = await makeContainer(
        MemoryStorage(),
        prefs: {'split': 'day', 'fileNameTemplate': 'x.timeclock'},
      );
      expect(
        c.read(settingsProvider).fileNameTemplate,
        '{yyyy}-{MM}-{dd}.timeclock',
      );
    });

    test(
      'the default template follows the split; a custom one is kept when valid',
      () async {
        final c = await makeContainer(MemoryStorage());
        final settings = c.read(settingsProvider.notifier);

        await settings.setSplit(SplitMethod.day);
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{yyyy}-{MM}-{dd}.timeclock',
        );

        await settings.setFileNameTemplate('d-{yyyy}-{MM}-{dd}.timeclock');
        await settings.setSplit(SplitMethod.month); // still works for month
        expect(
          c.read(settingsProvider).fileNameTemplate,
          'd-{yyyy}-{MM}-{dd}.timeclock',
        );

        await settings.setSplit(SplitMethod.week); // no {ww}: back to default
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{yyyy}-W{ww}.timeclock',
        );
      },
    );

    test(
      'split by project changes the default template and is saved',
      () async {
        final c = await makeContainer(MemoryStorage());
        final settings = c.read(settingsProvider.notifier);
        expect(c.read(settingsProvider).splitByProject, isFalse);

        await settings.setSplitByProject(true);
        expect(c.read(settingsProvider).splitByProject, isTrue);
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{project}-{yyyy}-{MM}.timeclock',
        );
        expect(c.read(settingsProvider).fileSettings.splitByProject, isTrue);

        await settings.setSplit(SplitMethod.week); // template follows both
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{project}-{yyyy}-W{ww}.timeclock',
        );

        await settings.setSplitByProject(false);
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{yyyy}-W{ww}.timeclock',
        );

        final saved = c.read(sharedPreferencesProvider);
        final again = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(saved)],
        );
        addTearDown(again.dispose);
        expect(again.read(settingsProvider).splitByProject, isFalse);
      },
    );

    test(
      'a custom template survives turning the option on only if it fits',
      () async {
        final c = await makeContainer(MemoryStorage());
        final settings = c.read(settingsProvider.notifier);

        await settings.setFileNameTemplate('hours-{yyyy}-{MM}.timeclock');
        await settings.setSplitByProject(true); // no {project}: back to default
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{project}-{yyyy}-{MM}.timeclock',
        );

        await settings.setFileNameTemplate('{project}/x.timeclock'); // invalid
        await settings.setFileNameTemplate('p-{project}-{yyyy}-{MM}.timeclock');
        await settings.setSplit(SplitMethod.month); // still fits
        expect(
          c.read(settingsProvider).fileNameTemplate,
          'p-{project}-{yyyy}-{MM}.timeclock',
        );
      },
    );

    test(
      'a stored template with {project} but the option off is replaced',
      () async {
        final c = await makeContainer(
          MemoryStorage(),
          prefs: {'fileNameTemplate': '{project}-{yyyy}-{MM}.timeclock'},
        );
        expect(
          c.read(settingsProvider).fileNameTemplate,
          '{yyyy}-{MM}.timeclock',
        );
      },
    );

    test(
      'with the option on, a template without {project} is rejected',
      () async {
        final c = await makeContainer(MemoryStorage());
        final settings = c.read(settingsProvider.notifier);
        await settings.setSplitByProject(true);
        expect(
          await settings.setFileNameTemplate('{yyyy}-{MM}.timeclock'),
          isNotNull,
        );
      },
    );

    test(
      'entries are written to project files when the option is on',
      () async {
        final storage = MemoryStorage();
        final c = await makeContainer(storage);
        await c.read(settingsProvider.notifier).setSplitByProject(true);
        await c.read(entriesProvider.notifier).start('work:a', at(30, 9));
        await c.read(entriesProvider.notifier).start('personal:b', at(30, 10));
        expect(storage.names, {
          'work-2026-10.timeclock',
          'personal-2026-10.timeclock',
        });
      },
    );

    test('invalid values are rejected and not saved', () async {
      final c = await makeContainer(MemoryStorage());
      final settings = c.read(settingsProvider.notifier);
      expect(await settings.setMetricsLevel(0), isNotNull);
      expect(await settings.setFileNameTemplate('nope.txt'), isNotNull);
      expect(c.read(settingsProvider).metricsLevel, 1);
      expect(
        c.read(settingsProvider).fileNameTemplate,
        '{yyyy}-{MM}.timeclock',
      );
    });
  });

  group('entries', () {
    test('loads existing files', () async {
      final c = await makeContainer(
        MemoryStorage({
          '2026-10.timeclock':
              'i 2026-10-30 09:00:00 a\no 2026-10-30 10:00:00 a\n'
              'i 2026-10-30 14:00:00 b\n',
        }),
      );
      expect(c.read(entriesProvider).requireValue.entries, hasLength(2));
      expect(c.read(runningProvider).single.entry.account, 'b');
      expect(finished(c).single.entry.account, 'a');
    });

    test('start, stop and the running list', () async {
      final storage = MemoryStorage();
      final c = await makeContainer(storage);
      final entries = c.read(entriesProvider.notifier);

      await entries.start('a', at(30, 9));
      await entries.start('b', at(30, 10));
      expect(c.read(runningProvider).map((e) => e.entry.account), ['b', 'a']);
      expect(storage.names, {'2026-10.timeclock'});

      await entries.stop(c.read(runningProvider).last, at(30, 11)); // a
      expect(c.read(runningProvider).single.entry.account, 'b');

      expect(await entries.stopAccount('b', at(30, 12)), isTrue);
      expect(await entries.stopAccount('b', at(30, 13)), isFalse);
      expect(c.read(runningProvider), isEmpty);
      expect(finished(c).map((e) => e.entry.account), ['b', 'a']);
    });

    test('start uses the configured split', () async {
      final storage = MemoryStorage();
      final c = await makeContainer(storage);
      await c.read(settingsProvider.notifier).setSplit(SplitMethod.day);
      await c.read(entriesProvider.notifier).start('a', at(30, 9));
      expect(storage.names, {'2026-10-30.timeclock'});
    });

    test('replace and remove', () async {
      final storage = MemoryStorage();
      final c = await makeContainer(storage);
      final entries = c.read(entriesProvider.notifier);
      await entries.start('a', at(30, 9));
      await entries.replace(
        c.read(runningProvider).single,
        account: 'a:b',
        start: at(30, 9),
        end: at(30, 10),
        comment: 'x',
      );
      expect(c.read(runningProvider), isEmpty);
      expect(finished(c).single.entry.comment, 'x');

      await entries.remove(finished(c).single);
      expect(c.read(entriesProvider).requireValue.entries, isEmpty);
    });

    test('invalid input throws and leaves the files alone', () async {
      final storage = MemoryStorage();
      final c = await makeContainer(storage);
      await expectLater(
        c.read(entriesProvider.notifier).start('a  b', at(30, 9)),
        throwsArgumentError,
      );
      expect(storage.names, isEmpty);
    });

    test('a stale entry reloads the files and reports the problem', () async {
      final storage = MemoryStorage({
        '2026-10.timeclock': 'i 2026-10-30 09:00:00 a\n',
      });
      final c = await makeContainer(storage);
      final stale = c.read(runningProvider).single;

      storage.externalWrite('2026-10.timeclock', 'i 2026-10-30 09:30:00 a\n');
      await expectLater(
        c.read(entriesProvider.notifier).stop(stale, at(30, 10)),
        throwsA(isA<StaleEntryException>()),
      );
      // The screen now shows the file as it is.
      expect(c.read(runningProvider).single.entry.start, at(30, 9, 30));
    });

    test('reloadIfChanged reads again only after an external change', () async {
      final storage = MemoryStorage();
      final c = await makeContainer(storage);
      final entries = c.read(entriesProvider.notifier);
      final before = c.read(entriesProvider).requireValue;

      await entries.reloadIfChanged();
      expect(identical(c.read(entriesProvider).requireValue, before), isTrue);

      storage.externalWrite('2026-10.timeclock', 'i 2026-10-30 09:00:00 a\n');
      await entries.reloadIfChanged();
      expect(c.read(runningProvider).single.entry.account, 'a');
    });

    test('a failing reload keeps the data on screen', () async {
      final storage = _FlakyStorage();
      final c = await makeContainer(storage);
      await c.read(entriesProvider.notifier).start('a', at(30, 9));
      storage.failing = true;
      await c.read(entriesProvider.notifier).reload();

      final state = c.read(entriesProvider);
      expect(state.hasError, isTrue);
      expect(state.value?.running, hasLength(1));
    });
  });

  group('derived', () {
    late MemoryStorage storage;
    late ProviderContainer c;

    setUp(() async {
      storage = MemoryStorage({
        '2026-10.timeclock':
            'i 2026-10-30 09:00:00 work:acme:dev\no 2026-10-30 11:00:00 work:acme:dev\n'
            'i 2026-10-30 11:00:00 work:acme:meet\no 2026-10-30 12:00:00 work:acme:meet\n'
            'i 2026-10-29 09:00:00 personal:read\no 2026-10-29 10:00:00 personal:read\n'
            'i 2026-10-28 09:00:00 work:acme:dev\no 2026-10-28 09:30:00 work:acme:dev\n'
            'i 2026-10-30 14:00:00 work:acme:dev\n',
      });
      c = await makeContainer(storage);
    });

    test('metrics per period, grouped by the configured level', () async {
      final today = c.read(metricsProvider(PeriodKind.today));
      expect(today.rows.map((r) => (r.account, r.duration)), [
        ('work', const Duration(hours: 4)), // 2h + 1h + 1h running
      ]);
      final week = c.read(metricsProvider(PeriodKind.week));
      expect(week.total, const Duration(hours: 5, minutes: 30));
    });

    test('changing the level in settings changes the metrics', () async {
      await c.read(settingsProvider.notifier).setMetricsLevel(3);
      final today = c.read(metricsProvider(PeriodKind.today));
      expect(today.rows.map((r) => r.account), [
        'work:acme:dev',
        'work:acme:meet',
      ]);
    });

    test('week start changes the week range', () async {
      // Sunday Oct 25 .. Saturday: includes the same days; check via Monday start
      // excluding nothing here, so compare a Sunday-only entry.
      storage.externalWrite(
        '2026-10.timeclock',
        '${storage.text('2026-10.timeclock')}'
            'i 2026-10-25 09:00:00 sun\no 2026-10-25 10:00:00 sun\n',
      );
      await c.read(entriesProvider.notifier).reload();
      expect(
        c.read(metricsProvider(PeriodKind.week)).rows.map((r) => r.account),
        isNot(contains('sun')),
      );
      await c.read(settingsProvider.notifier).setWeekStart(WeekStart.sunday);
      expect(
        c.read(metricsProvider(PeriodKind.week)).rows.map((r) => r.account),
        contains('sun'),
      );
    });

    test('suggestions and last account', () async {
      expect(c.read(accountSuggestionsProvider).first, 'work:acme:dev');
      expect(c.read(lastAccountProvider), 'work:acme:dev');
    });

    test('warnings are exposed', () async {
      storage.externalWrite('2026-11.timeclock', 'junk\n');
      await c.read(entriesProvider.notifier).reload();
      expect(c.read(warningsProvider).single.fileName, '2026-11.timeclock');
    });
  });
}

class _FlakyStorage extends MemoryStorage {
  bool failing = false;

  @override
  Future<List<StoredFile>> list() async {
    if (failing) throw StateError('disk gone');
    return super.list();
  }
}
