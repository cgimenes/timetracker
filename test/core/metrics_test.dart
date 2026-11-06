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
}
