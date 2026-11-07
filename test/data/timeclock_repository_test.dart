import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/file_naming.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/data/timeclock_repository.dart';

import '../support/memory_storage.dart';

DateTime d(int month, int day, [int h = 0, int m = 0]) =>
    DateTime(2026, month, day, h, m);

final monthly = FileSettings.defaults(SplitMethod.month);

void main() {
  late MemoryStorage storage;
  late TimeclockRepository repo;

  setUp(() {
    storage = MemoryStorage();
    repo = TimeclockRepository(storage);
  });

  group('load', () {
    test('reads every timeclock file and ignores others', () async {
      storage.externalWrite(
        '2026-09.timeclock',
        'i 2026-09-30 09:00:00 a\no 2026-09-30 10:00:00 a\n',
      );
      storage.externalWrite('2026-10.timeclock', 'i 2026-10-01 09:00:00 b\n');
      storage.externalWrite('notes.txt', 'i 2026-10-02 09:00:00 c\n');
      storage.externalWrite('2026-08.timeclock.txt', 'i x');

      final result = await repo.load();
      expect(result.files.map((f) => f.name), [
        '2026-09.timeclock',
        '2026-10.timeclock',
      ]);
      expect(result.entries.map((e) => (e.fileName, e.entry.account)), [
        ('2026-10.timeclock', 'b'),
        ('2026-09.timeclock', 'a'),
      ]);
      expect(result.running.single.entry.account, 'b');
    });

    test('collects warnings with their file', () async {
      storage.externalWrite('2026-10.timeclock', 'garbage\n');
      final result = await repo.load();
      expect(
        result.warnings.single.toString(),
        '2026-10.timeclock, line 1: malformed line',
      );
    });

    test('empty directory', () async {
      final result = await repo.load();
      expect(result.entries, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });

  group('hasChanged', () {
    test(
      'detects added, modified and removed files, not other files',
      () async {
        storage.externalWrite('2026-10.timeclock', 'i 2026-10-01 09:00:00 a\n');
        final loaded = await repo.load();
        expect(await repo.hasChanged(loaded), isFalse);

        storage.externalWrite('readme.txt', 'x');
        expect(await repo.hasChanged(loaded), isFalse);

        storage.externalWrite('2026-10.timeclock', 'i 2026-10-01 09:00:00 a\n');
        expect(await repo.hasChanged(loaded), isTrue); // same text, new mtime

        final again = await repo.load();
        storage.externalWrite('2026-11.timeclock', '');
        expect(await repo.hasChanged(again), isTrue);

        final third = await repo.load();
        storage.externalDelete('2026-11.timeclock');
        expect(await repo.hasChanged(third), isTrue);
      },
    );
  });

  group('start and stop', () {
    test('start creates the file of the start date', () async {
      await repo.startEntry(
        'a:b',
        d(10, 30, 9),
        comment: 'x',
        settings: monthly,
      );
      expect(
        storage.text('2026-10.timeclock'),
        'i 2026-10-30 09:00:00 a:b  x\n',
      );
    });

    test('start appends and keeps existing lines untouched', () async {
      storage.externalWrite(
        '2026-10.timeclock',
        '; mine\ni 2026-10-01 08:00:00   a   \n',
      );
      await repo.startEntry('b', d(10, 2, 9), settings: monthly);
      expect(
        storage.text('2026-10.timeclock'),
        '; mine\ni 2026-10-01 08:00:00   a   \ni 2026-10-02 09:00:00 b\n',
      );
    });

    test('start adds the newline a file without one was missing', () async {
      storage.externalWrite('2026-10.timeclock', 'i 2026-10-01 08:00:00 a');
      await repo.startEntry('b', d(10, 2, 9), settings: monthly);
      expect(
        storage.text('2026-10.timeclock'),
        'i 2026-10-01 08:00:00 a\ni 2026-10-02 09:00:00 b\n',
      );
    });

    test('start rejects an invalid account and writes nothing', () async {
      await expectLater(
        repo.startEntry('a  b', d(10, 2, 9), settings: monthly),
        throwsArgumentError,
      );
      expect(storage.names, isEmpty);
    });

    test('stop writes the clock-out in the file of the clock-in', () async {
      await repo.startEntry('a', d(10, 31, 23), settings: monthly);
      final running = (await repo.load()).running.single;
      await repo.stopEntry(running, d(11, 1, 1));
      expect(storage.names, {'2026-10.timeclock'});
      expect(
        storage.text('2026-10.timeclock'),
        'i 2026-10-31 23:00:00 a\no 2026-11-01 01:00:00 a\n',
      );
    });

    test('stopOldestRunning picks the account\'s oldest entry', () async {
      await repo.startEntry('a', d(10, 1, 9), settings: monthly);
      await repo.startEntry('b', d(10, 1, 9, 30), settings: monthly);
      await repo.startEntry('a', d(10, 1, 10), settings: monthly);

      expect(await repo.stopOldestRunning('a', d(10, 1, 11)), isTrue);
      final running = (await repo.load()).running;
      expect(running.map((e) => (e.entry.account, e.entry.start)), [
        ('a', d(10, 1, 10)),
        ('b', d(10, 1, 9, 30)),
      ]);
    });

    test('stopOldestRunning finds entries in older files', () async {
      await repo.startEntry('a', d(9, 30, 9), settings: monthly);
      expect(await repo.stopOldestRunning('a', d(10, 1, 9)), isTrue);
      expect(storage.names, {'2026-09.timeclock'});
      expect((await repo.load()).running, isEmpty);
    });

    test('stopOldestRunning returns false when nothing runs', () async {
      expect(await repo.stopOldestRunning('a', d(10, 1)), isFalse);
      await repo.startEntry('b', d(10, 1, 9), settings: monthly);
      expect(await repo.stopOldestRunning('a', d(10, 1, 10)), isFalse);
    });
  });

  group('replace and remove', () {
    const original =
        '; keep\n'
        'i 2026-10-01 09:00:00 a\n'
        'o 2026-10-01 10:00:00 a\n'
        'i 2026-10-02 09:00:00 b\n';

    setUp(() => storage.externalWrite('2026-10.timeclock', original));

    test('replace edits only the entry in place', () async {
      final stored = (await repo.load()).entries.last; // a, Oct 1
      await repo.replaceEntry(
        stored,
        account: 'c',
        start: d(10, 1, 9, 15),
        end: d(10, 1, 10, 15),
        comment: 'n',
        settings: monthly,
      );
      expect(
        storage.text('2026-10.timeclock'),
        '; keep\n'
        'i 2026-10-01 09:15:00 c  n\n'
        'o 2026-10-01 10:15:00 c\n'
        'i 2026-10-02 09:00:00 b\n',
      );
    });

    test('replace moves the entry when the start leaves the period', () async {
      final stored = (await repo.load()).entries.last;
      await repo.replaceEntry(
        stored,
        account: 'a',
        start: d(11, 2, 9),
        end: d(11, 2, 10),
        settings: monthly,
      );
      expect(
        storage.text('2026-11.timeclock'),
        'i 2026-11-02 09:00:00 a\no 2026-11-02 10:00:00 a\n',
      );
      expect(
        storage.text('2026-10.timeclock'),
        '; keep\ni 2026-10-02 09:00:00 b\n',
      );
    });

    test(
      'replace does not move entries just because settings changed',
      () async {
        final stored = (await repo.load()).entries.last;
        await repo.replaceEntry(
          stored,
          account: 'a',
          start: d(10, 1, 9, 30),
          end: d(10, 1, 10),
          settings: FileSettings.defaults(SplitMethod.none),
        );
        expect(storage.names, {'2026-10.timeclock'});
        expect(
          storage.text('2026-10.timeclock'),
          contains('i 2026-10-01 09:30:00 a'),
        );
      },
    );

    test('replace to a running entry in another file', () async {
      final stored = (await repo.load()).entries.last;
      await repo.replaceEntry(
        stored,
        account: 'a',
        start: d(11, 2, 9),
        settings: monthly,
      );
      expect(storage.text('2026-11.timeclock'), 'i 2026-11-02 09:00:00 a\n');
    });

    test('remove drops the entry lines only', () async {
      final stored = (await repo.load()).entries.last;
      await repo.removeEntry(stored);
      expect(
        storage.text('2026-10.timeclock'),
        '; keep\ni 2026-10-02 09:00:00 b\n',
      );
    });
  });

  group('files changed after load', () {
    test(
      'a line added above does not make replace hit the wrong entry',
      () async {
        storage.externalWrite(
          '2026-10.timeclock',
          'i 2026-10-01 09:00:00 a\no 2026-10-01 10:00:00 a\n',
        );
        final stored = (await repo.load()).entries.single;

        storage.externalWrite(
          '2026-10.timeclock',
          'i 2026-09-30 09:00:00 z\no 2026-09-30 10:00:00 z\n'
              'i 2026-10-01 09:00:00 a\no 2026-10-01 10:00:00 a\n',
        );
        await repo.removeEntry(stored);
        expect(
          storage.text('2026-10.timeclock'),
          'i 2026-09-30 09:00:00 z\no 2026-09-30 10:00:00 z\n',
        );
      },
    );

    test(
      'an entry edited elsewhere is reported stale and nothing is written',
      () async {
        storage.externalWrite('2026-10.timeclock', 'i 2026-10-01 09:00:00 a\n');
        final stored = (await repo.load()).entries.single;

        const edited = 'i 2026-10-01 09:30:00 a\n';
        storage.externalWrite('2026-10.timeclock', edited);
        await expectLater(
          repo.stopEntry(stored, d(10, 1, 11)),
          throwsA(isA<StaleEntryException>()),
        );
        await expectLater(
          repo.removeEntry(stored),
          throwsA(isA<StaleEntryException>()),
        );
        expect(storage.text('2026-10.timeclock'), edited);
      },
    );

    test('a file deleted after load makes its entries stale', () async {
      storage.externalWrite('2026-10.timeclock', 'i 2026-10-01 09:00:00 a\n');
      final stored = (await repo.load()).entries.single;
      storage.externalDelete('2026-10.timeclock');
      await expectLater(
        repo.removeEntry(stored),
        throwsA(isA<StaleEntryException>()),
      );
      expect(storage.names, isEmpty);
    });
  });

  test('providers wire the repository to the overridden storage', () async {
    final container = ProviderContainer(
      overrides: [timeclockStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final repository = container.read(timeclockRepositoryProvider);
    await repository.startEntry('a', d(10, 1, 9), settings: monthly);
    expect(storage.text('2026-10.timeclock'), 'i 2026-10-01 09:00:00 a\n');
  });
}
