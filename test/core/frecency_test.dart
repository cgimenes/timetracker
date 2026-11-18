import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/frecency.dart';
import 'package:timetracker/core/timeclock.dart';

final now = DateTime(2026, 10, 30, 12);

Entry entry(String account, Duration ago) => Entry(
  inIndex: 0,
  outIndex: null,
  account: account,
  start: now.subtract(ago),
  end: null,
  comment: null,
);

void main() {
  test('frequent accounts beat rare ones', () {
    final ranked = rankAccounts([
      entry('rare', const Duration(hours: 1)),
      entry('often', const Duration(hours: 2)),
      entry('often', const Duration(hours: 3)),
    ], now);
    expect(ranked, ['often', 'rare']);
  });

  test('recent use beats old frequent use', () {
    final ranked = rankAccounts([
      for (var i = 0; i < 3; i++) entry('old', Duration(days: 100 + i)),
      entry('new', const Duration(days: 1)),
    ], now);
    // 3 * 10 = 30 for old, 100 for new.
    expect(ranked, ['new', 'old']);
  });

  test('age buckets', () {
    int score(Duration ago) => rankAccounts([entry('a', ago)], now).length;
    expect(score(const Duration(days: 1)), 1); // sanity: listed once

    // Compare buckets pairwise through ordering.
    bool beats(Duration newer, Duration older) =>
        rankAccounts([entry('x', older), entry('y', newer)], now).first == 'y';
    expect(beats(const Duration(days: 3), const Duration(days: 5)), isTrue);
    expect(beats(const Duration(days: 13), const Duration(days: 20)), isTrue);
    expect(beats(const Duration(days: 30), const Duration(days: 60)), isTrue);
    expect(beats(const Duration(days: 89), const Duration(days: 120)), isTrue);
  });

  test('ties go to the most recent, then alphabetical', () {
    expect(
      rankAccounts([
        entry('a', const Duration(hours: 5)),
        entry('b', const Duration(hours: 1)),
      ], now),
      ['b', 'a'],
    );
    expect(
      rankAccounts([
        entry('b', const Duration(hours: 1)),
        entry('a', const Duration(hours: 1)),
      ], now),
      ['a', 'b'],
    );
  });

  test('no entries', () {
    expect(rankAccounts(const [], now), isEmpty);
    expect(lastClosedAccount(const []), isNull);
  });

  test('rankProjects groups the accounts of a project', () {
    final ranked = rankProjects([
      entry('work:acme:dev', const Duration(days: 1)),
      entry('work:globex:dev', const Duration(days: 2)),
      entry('personal:read', const Duration(hours: 1)),
      entry('old', const Duration(days: 200)),
    ], now);
    // work: 200 (two recent uses), personal: 100, old: 10.
    expect(ranked, ['work', 'personal', 'old']);
  });

  test('recentUses gives the latest start of each account', () {
    final uses = recentUses([
      entry('a', const Duration(days: 3)),
      entry('b', const Duration(days: 2)),
      entry('a', const Duration(days: 1)),
    ], 5);
    expect([for (final u in uses) u.account], ['a', 'b']);
    expect(uses.first.start, now.subtract(const Duration(days: 1)));
  });

  test('recentAccounts: newest first, each account once', () {
    final entries = [
      entry('old', const Duration(days: 9)),
      entry('a', const Duration(days: 3)),
      entry('b', const Duration(days: 2)),
      entry('a', const Duration(days: 1)),
      entry('c', const Duration(hours: 1)),
    ];
    expect(recentAccounts(entries, 3), ['c', 'a', 'b']);
    expect(recentAccounts(entries, 2), ['c', 'a']);
    expect(recentAccounts(entries, 10), ['c', 'a', 'b', 'old']);
    expect(recentAccounts(const [], 3), isEmpty);
  });

  test('recentAccounts skips excluded accounts before counting', () {
    final entries = [
      entry('a', const Duration(days: 3)),
      entry('b', const Duration(days: 2)),
      entry('c', const Duration(days: 1)),
      entry('d', const Duration(hours: 1)),
    ];
    expect(recentAccounts(entries, 2, exclude: {'d'}), ['c', 'b']);
  });

  test('lastClosedAccount is the one that ended last, running ignored', () {
    Entry closed(String account, Duration endedAgo) => Entry(
      inIndex: 0,
      outIndex: 1,
      account: account,
      start: now.subtract(endedAgo + const Duration(hours: 1)),
      end: now.subtract(endedAgo),
      comment: null,
    );
    expect(
      lastClosedAccount([
        closed('old', const Duration(days: 2)),
        entry('running', const Duration(minutes: 5)),
        closed('latest', const Duration(hours: 1)),
        closed('mid', const Duration(hours: 5)),
      ]),
      'latest',
    );
  });
}
