import 'account.dart';
import 'timeclock.dart';

enum PeriodKind { today, week, month }

enum WeekStart {
  monday(DateTime.monday),
  sunday(DateTime.sunday);

  const WeekStart(this.weekday);
  final int weekday;
}

/// Half-open range: [start, end).
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

DateRange periodRange(
  PeriodKind kind,
  DateTime now, {
  WeekStart weekStart = WeekStart.monday,
}) {
  switch (kind) {
    case PeriodKind.today:
      return DateRange(
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day + 1),
      );
    case PeriodKind.week:
      final back = (now.weekday - weekStart.weekday + 7) % 7;
      return DateRange(
        DateTime(now.year, now.month, now.day - back),
        DateTime(now.year, now.month, now.day - back + 7),
      );
    case PeriodKind.month:
      return DateRange(
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      );
  }
}

/// Time of [entry] that falls inside [range]. Running entries count up to
/// [now].
Duration overlap(Entry entry, DateRange range, DateTime now) {
  final end = entry.end ?? now;
  final from = entry.start.isAfter(range.start) ? entry.start : range.start;
  final to = end.isBefore(range.end) ? end : range.end;
  final d = to.difference(from);
  return d.isNegative ? Duration.zero : d;
}

class AccountTotal {
  const AccountTotal(this.account, this.duration);
  final String account;
  final Duration duration;
}

class Metrics {
  const Metrics(this.rows, this.total);

  /// Longest first; ties in alphabetical order.
  final List<AccountTotal> rows;
  final Duration total;
}

/// Sums time per account truncated to [level], counting only the part of
/// each entry inside [range].
Metrics computeMetrics(
  Iterable<Entry> entries,
  DateRange range, {
  required int level,
  required DateTime now,
}) {
  final sums = <String, Duration>{};
  var total = Duration.zero;
  for (final e in entries) {
    final d = overlap(e, range, now);
    if (d == Duration.zero) continue;
    final key = truncateAccount(e.account, level);
    sums[key] = (sums[key] ?? Duration.zero) + d;
    total += d;
  }
  final rows = [for (final kv in sums.entries) AccountTotal(kv.key, kv.value)]
    ..sort((a, b) {
      final byTime = b.duration.compareTo(a.duration);
      return byTime != 0 ? byTime : a.account.compareTo(b.account);
    });
  return Metrics(rows, total);
}

/// How the Metrics chart groups time.
enum Grouping { day, week, month }

/// Time tracked in one day, week or month, per account group.
class Bucket {
  const Bucket(this.range, this.label, this.byAccount);

  final DateRange range;

  /// Short label for the axis: `30`, `10-26` (first day of the week), `Oct`.
  final String label;

  /// Time per account cut to the chart level.
  final Map<String, Duration> byAccount;

  Duration get total =>
      byAccount.values.fold(Duration.zero, (sum, d) => sum + d);
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Time tracked per day, week or month, oldest first, the last one holding
/// [now]. By default 14 days, 12 weeks or 12 months; [count] changes that.
///
/// Time is split per account cut to [level]. Entries crossing a boundary
/// count only for the part inside each bucket, and running entries count up
/// to [now].
List<Bucket> bucketTotals(
  Iterable<Entry> entries,
  Grouping grouping,
  DateTime now, {
  required int level,
  WeekStart weekStart = WeekStart.monday,
  int? count,
}) {
  final n =
      count ??
      switch (grouping) {
        Grouping.day => 14,
        Grouping.week => 12,
        Grouping.month => 12,
      };
  final list = entries.toList();
  final thisWeek = periodRange(PeriodKind.week, now, weekStart: weekStart);

  final buckets = <Bucket>[];
  for (var i = n - 1; i >= 0; i--) {
    final DateRange range;
    final String label;
    switch (grouping) {
      case Grouping.day:
        final d = DateTime(now.year, now.month, now.day - i);
        range = DateRange(d, DateTime(d.year, d.month, d.day + 1));
        label = '${d.day}';
      case Grouping.week:
        final start = DateTime(
          thisWeek.start.year,
          thisWeek.start.month,
          thisWeek.start.day - 7 * i,
        );
        range = DateRange(
          start,
          DateTime(start.year, start.month, start.day + 7),
        );
        label = '${_two(start.month)}-${_two(start.day)}';
      case Grouping.month:
        final start = DateTime(now.year, now.month - i);
        range = DateRange(start, DateTime(start.year, start.month + 1));
        label = _monthNames[start.month - 1];
    }
    final sums = <String, Duration>{};
    for (final e in list) {
      final d = overlap(e, range, now);
      if (d == Duration.zero) continue;
      final key = truncateAccount(e.account, level);
      sums[key] = (sums[key] ?? Duration.zero) + d;
    }
    buckets.add(Bucket(range, label, sums));
  }
  return buckets;
}
