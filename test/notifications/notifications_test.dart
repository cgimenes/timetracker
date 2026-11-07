import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetracker/core/timeclock.dart';
import 'package:timetracker/data/providers.dart';
import 'package:timetracker/data/timeclock_repository.dart';
import 'package:timetracker/notifications/providers.dart';
import 'package:timetracker/notifications/running_content.dart';
import 'package:timetracker/notifications/running_notifier.dart';
import 'package:timetracker/state/entries.dart';

import '../support/memory_storage.dart';

DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 30, h, m);

StoredEntry running(String account, DateTime start) => StoredEntry(
  '2026-10.timeclock',
  Entry(
    inIndex: 0,
    outIndex: null,
    account: account,
    start: start,
    end: null,
    comment: null,
  ),
);

void main() {
  group('buildRunningContent', () {
    test('nothing running means no notification', () {
      expect(buildRunningContent(const []), isNull);
    });

    test('one entry', () {
      final c = buildRunningContent([running('work:acme:dev', at(9, 5))])!;
      expect(c.title, 'work:acme:dev');
      expect(c.body, 'work:acme:dev');
      expect(c.lines, ['work:acme:dev (since 09:05)']);
      expect(c.since, at(9, 5));
      expect(c.actions.single.id, 'stop:work:acme:dev');
      expect(c.actions.single.label, 'Stop dev');
    });

    test('several entries, oldest first, timer from the oldest', () {
      final c = buildRunningContent([
        running('b', at(11)),
        running('a', at(9)),
      ])!;
      expect(c.title, '2 running');
      expect(c.body, 'a, b');
      expect(c.lines, ['a (since 09:00)', 'b (since 11:00)']);
      expect(c.since, at(9));
      expect(c.actions.map((a) => a.id), ['stop:a', 'stop:b']);
    });

    test('at most three Stop actions, the rest is mentioned', () {
      final c = buildRunningContent([
        for (var i = 0; i < 5; i++) running('a$i', at(9 + i)),
      ])!;
      expect(c.actions, hasLength(3));
      expect(c.actions.map((a) => a.id), ['stop:a0', 'stop:a1', 'stop:a2']);
      expect(c.lines, hasLength(6));
      expect(c.lines.last, '+2 more, stop them in the app');
    });
  });

  group('action ids', () {
    test('round trip, including colons in the account', () {
      expect(
        accountFromActionId(stopActionId('work:acme:dev')),
        'work:acme:dev',
      );
    });

    test('other actions and missing ids give null', () {
      expect(accountFromActionId(null), isNull);
      expect(accountFromActionId('open'), isNull);
      expect(accountFromActionId('stop:'), isNull);
    });
  });

  test('runningSignature changes with the set of running entries', () {
    final a = running('a', at(9));
    final b = running('b', at(10));
    expect(runningSignature([a, b]), isNot(runningSignature([a])));
    expect(runningSignature([a]), runningSignature([running('a', at(9))]));
    expect(runningSignature(const []), '');
  });

  group('notificationSyncProvider', () {
    late MemoryStorage storage;
    late _FakeNotifier notifier;
    late ProviderContainer container;

    Future<void> start() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          timeclockStorageProvider.overrideWithValue(storage),
          runningNotifierProvider.overrideWithValue(notifier),
        ],
      );
      addTearDown(container.dispose);
      container.read(notificationSyncProvider);
      await container.read(entriesProvider.future);
    }

    setUp(() {
      storage = MemoryStorage();
      notifier = _FakeNotifier();
    });

    test('shows entries already running at startup', () async {
      storage.externalWrite('2026-10.timeclock', 'i 2026-10-30 09:00:00 a\n');
      await start();
      expect(notifier.calls, ['a']);
    });

    test('waits for the first load before touching the notification', () async {
      storage.externalWrite('2026-10.timeclock', 'i 2026-10-30 09:00:00 a\n');
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          timeclockStorageProvider.overrideWithValue(storage),
          runningNotifierProvider.overrideWithValue(notifier),
        ],
      );
      addTearDown(container.dispose);
      container.read(notificationSyncProvider);
      expect(notifier.calls, isEmpty); // no sync([]) while loading
      await container.read(entriesProvider.future);
      expect(notifier.calls, ['a']);
    });

    test('follows start and stop, and skips redundant updates', () async {
      await start();
      expect(notifier.calls, ['']); // loaded, nothing running

      final entries = container.read(entriesProvider.notifier);
      await entries.start('a', at(9));
      await entries.start('b', at(10));
      await entries.reload(); // same content: no extra call
      await entries.stopAccount('a', at(11));
      await entries.stopAccount('b', at(12));

      expect(notifier.calls, ['', 'a', 'b,a', 'b', '']);
    });

    test('reacts to files changed from outside after a reload', () async {
      await start();
      storage.externalWrite('2026-10.timeclock', 'i 2026-10-30 09:00:00 z\n');
      await container.read(entriesProvider.notifier).reloadIfChanged();
      expect(notifier.calls.last, 'z');
    });
  });
}

class _FakeNotifier implements RunningNotifier {
  final calls = <String>[];

  @override
  Future<void> sync(List<StoredEntry> running) async =>
      calls.add(running.map((s) => s.entry.account).join(','));
}
