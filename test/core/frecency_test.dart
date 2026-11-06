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
    expect(lastUsedAccount(const []), isNull);
  });

  test('lastUsedAccount is the most recently started', () {
    expect(
      lastUsedAccount([
        entry('old', const Duration(days: 2)),
        entry('latest', const Duration(minutes: 5)),
        entry('mid', const Duration(hours: 5)),
      ]),
      'latest',
    );
  });
}
