import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/budget.dart';
import '../core/frecency.dart';
import '../core/metrics.dart';
import '../core/timeclock.dart';
import '../data/timeclock_repository.dart';
import '../settings/app_settings.dart';
import 'budgets.dart';
import 'clock.dart';
import 'entries.dart';

List<StoredEntry> _entries(Ref ref) =>
    ref.watch(entriesProvider).value?.entries ?? const [];

/// Running entries, newest first.
final runningProvider = Provider<List<StoredEntry>>(
  (ref) => _entries(ref).where((e) => e.entry.isRunning).toList(),
);

/// Time per account at the configured level, for Today, This week and This
/// month.
final metricsProvider = Provider.family<Metrics, PeriodKind>((ref, kind) {
  final now = nowOf(ref);
  final settings = ref.watch(settingsProvider);
  return computeMetrics(
    _entries(ref).map((e) => e.entry),
    periodRange(kind, now, weekStart: settings.weekStart),
    level: settings.metricsLevel,
    now: now,
  );
});

/// Accounts to suggest when starting an entry, best first.
final accountSuggestionsProvider = Provider<List<String>>(
  (ref) => rankAccounts(_entries(ref).map((e) => e.entry), nowOf(ref)),
);

/// Account to prefill in the add form.
final lastAccountProvider = Provider<String?>(
  (ref) => lastUsedAccount(_entries(ref).map((e) => e.entry)),
);

/// Problems found while reading the files (malformed lines, orphan clock-outs).
final warningsProvider = Provider<List<FileWarning>>(
  (ref) => ref.watch(entriesProvider).value?.warnings ?? const [],
);

/// How much of a budget is used.
class BudgetProgress {
  const BudgetProgress(this.budget, this.used);

  final Budget budget;
  final Duration used;

  String get project => budget.project;
  Duration get allowed => budget.amount;

  /// The time asked for was reached.
  bool get achieved => allowed > Duration.zero && used >= allowed;

  /// 0 to 1, for a progress bar.
  double get fraction => allowed == Duration.zero
      ? 0
      : (used.inSeconds / allowed.inSeconds).clamp(0, 1);
}

/// Every budget with the time its project used inside the budget's window. A
/// recurring budget is measured against the current day, week or month.
final budgetProgressProvider = Provider<List<BudgetProgress>>((ref) {
  if (!ref.watch(settingsProvider.select((s) => s.budgetsEnabled))) {
    return const [];
  }
  final budgets = ref.watch(budgetsProvider).value?.budgets ?? const [];
  if (budgets.isEmpty) return const [];
  final now = nowOf(ref);
  final weekStart = ref.watch(settingsProvider.select((s) => s.weekStart));
  final entries = _entries(ref).map((e) => e.entry).toList();

  return [
    for (final b in budgets)
      BudgetProgress(b, _usedBy(entries, b, now, weekStart)),
  ];
});

Duration _usedBy(
  List<Entry> entries,
  Budget b,
  DateTime now,
  WeekStart weekStart,
) {
  final w = b.window;
  final range = w.recurring
      ? periodRange(w.period.kind, now, weekStart: weekStart)
      : DateRange(w.from!, w.to!);
  final metrics = computeMetrics(entries, range, level: 1, now: now);
  return metrics.rows
      .where((r) => r.account == b.project)
      .fold(Duration.zero, (sum, r) => sum + r.duration);
}

/// Budgets that apply now to the period of [kind], for the Metrics cards: the
/// recurring ones, and the one for the current day, week or month.
final metricsBudgetsProvider =
    Provider.family<List<BudgetProgress>, PeriodKind>((ref, kind) {
      final now = nowOf(ref);
      return [
        for (final p in ref.watch(budgetProgressProvider))
          if (p.budget.period.kind == kind && p.budget.window.contains(now)) p,
      ]..sort((a, b) => a.project.compareTo(b.project));
    });

/// How the Metrics chart groups time. Not saved: it starts on days.
final chartGroupingProvider = NotifierProvider<ChartGroupingNotifier, Grouping>(
  ChartGroupingNotifier.new,
);

class ChartGroupingNotifier extends Notifier<Grouping> {
  @override
  Grouping build() => Grouping.day;

  void set(Grouping grouping) => state = grouping;
}

/// Time per day, week or month for the chart, at the Metrics level.
final chartBucketsProvider = Provider<List<Bucket>>((ref) {
  final settings = ref.watch(settingsProvider);
  return bucketTotals(
    _entries(ref).map((e) => e.entry),
    ref.watch(chartGroupingProvider),
    nowOf(ref),
    level: settings.metricsLevel,
    weekStart: settings.weekStart,
  );
});
