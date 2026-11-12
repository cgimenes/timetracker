import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/metrics.dart';
import 'package:timetracker/core/timeclock.dart';

// Friday 2026-10-30.
final now = DateTime(2026, 10, 30, 15);

Entry entry(String account, DateTime start, [DateTime? end]) => Entry(
  inIndex: 0,
  outIndex: end == null ? null : 1,
  account: account,
  start: start,
  end: end,
  comment: null,
);

void main() {
  group('periodRange', () {
    test('today', () {
      final r = periodRange(PeriodKind.today, now);
      expect(r.start, DateTime(2026, 10, 30));
      expect(r.end, DateTime(2026, 10, 31));
    });

    test('week starting on Monday', () {
      final r = periodRange(PeriodKind.week, now);
      expect(r.start, DateTime(2026, 10, 26));
      expect(r.end, DateTime(2026, 11, 2));
    });

    test('week starting on Sunday', () {
      final r = periodRange(PeriodKind.week, now, weekStart: WeekStart.sunday);
      expect(r.start, DateTime(2026, 10, 25));
      expect(r.end, DateTime(2026, 11, 1));
    });

    test('week when today is the first day', () {
      final monday = DateTime(2026, 10, 26, 8);
      expect(
        periodRange(PeriodKind.week, monday).start,
        DateTime(2026, 10, 26),
      );
      final sunday = DateTime(2026, 10, 25, 8);
      expect(
        periodRange(PeriodKind.week, sunday, weekStart: WeekStart.sunday).start,
        DateTime(2026, 10, 25),
      );
      // A Sunday belongs to the week that started the Monday before.
      expect(
        periodRange(PeriodKind.week, sunday).start,
        DateTime(2026, 10, 19),
      );
    });

    test('month, including December', () {
      final r = periodRange(PeriodKind.month, now);
      expect(r.start, DateTime(2026, 10));
      expect(r.end, DateTime(2026, 11));
      final dec = periodRange(PeriodKind.month, DateTime(2026, 12, 15));
      expect(dec.end, DateTime(2027));
    });
  });

  group('overlap', () {
    final today = periodRange(PeriodKind.today, now);

    test('entry fully inside', () {
      expect(
        overlap(
          entry('a', DateTime(2026, 10, 30, 9), DateTime(2026, 10, 30, 10)),
          today,
          now,
        ),
        const Duration(hours: 1),
      );
    });

    test('entry crossing midnight counts only the part inside', () {
      final e = entry(
        'a',
        DateTime(2026, 10, 29, 23),
        DateTime(2026, 10, 30, 1),
      );
      expect(overlap(e, today, now), const Duration(hours: 1));
      final yesterday = DateRange(
        DateTime(2026, 10, 29),
        DateTime(2026, 10, 30),
      );
      expect(overlap(e, yesterday, now), const Duration(hours: 1));
    });

    test('running entry counts up to now', () {
      expect(
        overlap(entry('a', DateTime(2026, 10, 30, 14)), today, now),
        const Duration(hours: 1),
      );
    });

    test('running entry from days ago is clipped to the period', () {
      expect(
        overlap(entry('a', DateTime(2026, 10, 27, 9)), today, now),
        const Duration(hours: 15),
      );
    });

    test('entries outside the range or in the future count nothing', () {
      expect(
        overlap(
          entry('a', DateTime(2026, 10, 28, 9), DateTime(2026, 10, 28, 10)),
          today,
          now,
        ),
        Duration.zero,
      );
      expect(
        overlap(entry('a', DateTime(2026, 10, 30, 18)), today, now),
        Duration.zero,
      );
    });
  });

  group('computeMetrics', () {
    final entries = [
      entry(
        'work:acme:dev',
        DateTime(2026, 10, 30, 9),
        DateTime(2026, 10, 30, 11),
      ),
      entry(
        'work:acme:meet',
        DateTime(2026, 10, 30, 11),
        DateTime(2026, 10, 30, 12),
      ),
      entry(
        'personal:read',
        DateTime(2026, 10, 30, 12),
        DateTime(2026, 10, 30, 12, 30),
      ),
      entry(
        'work:acme:dev',
        DateTime(2026, 10, 29, 9),
        DateTime(2026, 10, 29, 10),
      ),
    ];
    final today = periodRange(PeriodKind.today, now);

    test('level 1 groups by first segment, longest first', () {
      final m = computeMetrics(entries, today, level: 1, now: now);
      expect(m.rows.map((r) => (r.account, r.duration)), [
        ('work', const Duration(hours: 3)),
        ('personal', const Duration(minutes: 30)),
      ]);
      expect(m.total, const Duration(hours: 3, minutes: 30));
    });

    test('level 2 and 3', () {
      final l2 = computeMetrics(entries, today, level: 2, now: now);
      expect(l2.rows.map((r) => r.account), ['work:acme', 'personal:read']);
      final l3 = computeMetrics(entries, today, level: 3, now: now);
      expect(l3.rows.map((r) => r.account), [
        'work:acme:dev',
        'work:acme:meet',
        'personal:read',
      ]);
    });

    test('week includes the previous day', () {
      final week = periodRange(PeriodKind.week, now);
      final m = computeMetrics(entries, week, level: 1, now: now);
      expect(m.total, const Duration(hours: 4, minutes: 30));
    });

    test('ties are alphabetical and empty periods give no rows', () {
      final tie = [
        entry('b', DateTime(2026, 10, 30, 9), DateTime(2026, 10, 30, 10)),
        entry('a', DateTime(2026, 10, 30, 10), DateTime(2026, 10, 30, 11)),
      ];
      expect(
        computeMetrics(
          tie,
          today,
          level: 1,
          now: now,
        ).rows.map((r) => r.account),
        ['a', 'b'],
      );
      final empty = computeMetrics(const [], today, level: 1, now: now);
      expect(empty.rows, isEmpty);
      expect(empty.total, Duration.zero);
    });
  });

  group('bucketTotals', () {
    DateTime d(int month, int day, [int h = 0, int m = 0]) =>
        DateTime(2026, month, day, h, m);

    test('days: 14 by default, oldest first, the last one holds now', () {
      final b = bucketTotals([], Grouping.day, now, level: 1);
      expect(b, hasLength(14));
      expect(b.first.range.start, d(10, 17));
      expect(b.last.range.start, d(10, 30));
      expect(b.last.range.end, d(10, 31));
      expect(b.map((x) => x.label).take(3), ['17', '18', '19']);
    });

    test('sums per account at the level, per day', () {
      final b = bucketTotals(
        [
          entry('work:acme:dev', d(10, 30, 9), d(10, 30, 11)),
          entry('work:globex', d(10, 30, 11), d(10, 30, 11, 30)),
          entry('personal:read', d(10, 29, 9), d(10, 29, 10)),
        ],
        Grouping.day,
        now,
        level: 1,
      );
      expect(b.last.byAccount, {'work': const Duration(hours: 2, minutes: 30)});
      expect(b.last.total, const Duration(hours: 2, minutes: 30));
      expect(b[12].byAccount, {'personal': const Duration(hours: 1)});

      final deep = bucketTotals(
        [
          entry('work:acme:dev', d(10, 30, 9), d(10, 30, 11)),
          entry('work:globex', d(10, 30, 11), d(10, 30, 11, 30)),
        ],
        Grouping.day,
        now,
        level: 2,
      );
      expect(deep.last.byAccount.keys.toSet(), {'work:acme', 'work:globex'});
    });

    test('an entry across midnight counts in both days', () {
      final b = bucketTotals(
        [entry('a', d(10, 29, 23), d(10, 30, 2))],
        Grouping.day,
        now,
        level: 1,
      );
      expect(b[12].total, const Duration(hours: 1));
      expect(b[13].total, const Duration(hours: 2));
    });

    test('a running entry counts up to now', () {
      final b = bucketTotals(
        [entry('a', d(10, 30, 14))],
        Grouping.day,
        now,
        level: 1,
      );
      expect(b.last.total, const Duration(hours: 1));
    });

    test('weeks: 12, starting on Monday, labeled by their first day', () {
      final b = bucketTotals([], Grouping.week, now, level: 1);
      expect(b, hasLength(12));
      expect(b.last.range.start, d(10, 26));
      expect(b.last.range.end, d(11, 2));
      expect(b.last.label, '10-26');
      expect(b[10].range.start, d(10, 19));
    });

    test('weeks can start on Sunday', () {
      final b = bucketTotals(
        [entry('a', d(10, 25, 9), d(10, 25, 10))],
        Grouping.week,
        now,
        level: 1,
        weekStart: WeekStart.sunday,
      );
      expect(b.last.range.start, d(10, 25));
      expect(b.last.total, const Duration(hours: 1));
    });

    test('weeks cut an entry at the week boundary', () {
      final b = bucketTotals(
        [entry('a', d(10, 25, 23), d(10, 26, 1))],
        Grouping.week,
        now,
        level: 1,
        count: 2,
      );
      expect(b[0].total, const Duration(hours: 1));
      expect(b[1].total, const Duration(hours: 1));
    });

    test('months: 12, across the year, with month names', () {
      final b = bucketTotals([], Grouping.month, now, level: 1);
      expect(b, hasLength(12));
      expect(b.last.range.start, d(10, 1));
      expect(b.last.range.end, d(11, 1));
      expect(b.last.label, 'Oct');
      expect(b.first.range.start, DateTime(2025, 11));
      expect(b.first.label, 'Nov');
    });

    test('months sum the whole month', () {
      final b = bucketTotals(
        [
          entry('a', d(10, 1, 9), d(10, 1, 10)),
          entry('a', d(10, 20, 9), d(10, 20, 12)),
          entry('a', d(9, 30, 9), d(9, 30, 10)),
        ],
        Grouping.month,
        now,
        level: 1,
      );
      expect(b.last.total, const Duration(hours: 4));
      expect(b[10].total, const Duration(hours: 1));
    });

    test('count changes the number of buckets', () {
      expect(
        bucketTotals([], Grouping.day, now, level: 1, count: 3),
        hasLength(3),
      );
    });
  });
}
