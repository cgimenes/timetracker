import 'account.dart';
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
List<String> rankAccounts(Iterable<Entry> entries, DateTime now) =>
    _rank(entries, now, (e) => e.account);

/// Projects (first account level) ordered by frecency, like [rankAccounts].
List<String> rankProjects(Iterable<Entry> entries, DateTime now) =>
    _rank(entries, now, (e) => projectOf(e.account));

List<String> _rank(
  Iterable<Entry> entries,
  DateTime now,
  String Function(Entry) keyOf,
) {
  final score = <String, int>{};
  final last = <String, DateTime>{};
  for (final e in entries) {
    final key = keyOf(e);
    score[key] = (score[key] ?? 0) + _weight(now.difference(e.start));
    final seen = last[key];
    if (seen == null || e.start.isAfter(seen)) last[key] = e.start;
  }
  return score.keys.toList()..sort((a, b) {
    final byScore = score[b]!.compareTo(score[a]!);
    if (byScore != 0) return byScore;
    final byLast = last[b]!.compareTo(last[a]!);
    return byLast != 0 ? byLast : a.compareTo(b);
  });
}

/// Accounts of the most recently started entries, newest first, each once,
/// with the start of its latest entry. Accounts in [exclude] are skipped.
List<({String account, DateTime start})> recentUses(
  Iterable<Entry> entries,
  int count, {
  Set<String> exclude = const {},
}) {
  final sorted = entries.toList()..sort((a, b) => b.start.compareTo(a.start));
  final result = <({String account, DateTime start})>[];
  for (final e in sorted) {
    if (result.length >= count) break;
    if (exclude.contains(e.account) ||
        result.any((u) => u.account == e.account)) {
      continue;
    }
    result.add((account: e.account, start: e.start));
  }
  return result;
}

/// Accounts of the most recently started entries, newest first, each once.
/// Accounts in [exclude] are skipped.
List<String> recentAccounts(
  Iterable<Entry> entries,
  int count, {
  Set<String> exclude = const {},
}) => [for (final u in recentUses(entries, count, exclude: exclude)) u.account];

/// Account of the closed entry that ended last.
String? lastClosedAccount(Iterable<Entry> entries) {
  Entry? latest;
  for (final e in entries) {
    final end = e.end;
    if (end == null) continue;
    if (latest == null || end.isAfter(latest.end!)) latest = e;
  }
  return latest?.account;
}
