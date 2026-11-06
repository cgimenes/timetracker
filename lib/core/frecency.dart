import 'timeclock.dart';

/// Weight of one use, by age. Same buckets Firefox uses for frecency.
int _weight(Duration age) {
  final days = age.inDays;
  if (days < 4) return 100;
  if (days < 14) return 70;
  if (days < 31) return 50;
  if (days < 90) return 30;
  return 10;
}

/// Accounts ordered by frecency: frequency of use weighted by recency.
/// Ties go to the most recently used, then alphabetical order.
List<String> rankAccounts(Iterable<Entry> entries, DateTime now) {
  final score = <String, int>{};
  final last = <String, DateTime>{};
  for (final e in entries) {
    score[e.account] =
        (score[e.account] ?? 0) + _weight(now.difference(e.start));
    final seen = last[e.account];
    if (seen == null || e.start.isAfter(seen)) last[e.account] = e.start;
  }
  return score.keys.toList()..sort((a, b) {
    final byScore = score[b]!.compareTo(score[a]!);
    if (byScore != 0) return byScore;
    final byLast = last[b]!.compareTo(last[a]!);
    return byLast != 0 ? byLast : a.compareTo(b);
  });
}

/// Account of the most recently started entry.
String? lastUsedAccount(Iterable<Entry> entries) {
  Entry? latest;
  for (final e in entries) {
    if (latest == null || e.start.isAfter(latest.start)) latest = e;
  }
  return latest?.account;
}
