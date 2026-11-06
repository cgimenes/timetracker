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
