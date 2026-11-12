import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/frecency.dart';
import '../core/metrics.dart';
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
  const BudgetProgress(this.project, this.used, this.budget);

  final String project;
  final Duration used;
  final Duration budget;

  bool get over => used > budget;

  /// 0 to 1, for a progress bar.
  double get fraction => budget == Duration.zero
      ? 0
      : (used.inSeconds / budget.inSeconds).clamp(0, 1);
}

/// Budgets of the period of [kind], with the time used so far by each project.
/// Independent of the Metrics level: a budget is always for a project.
final budgetProgressProvider =
    Provider.family<List<BudgetProgress>, PeriodKind>((ref, kind) {
      final budgets = (ref.watch(budgetsProvider).value?.budgets ?? const [])
          .where((b) => b.period.kind == kind)
          .toList();
      if (budgets.isEmpty) return const [];
      final now = nowOf(ref);
      final settings = ref.watch(settingsProvider);
      final used = computeMetrics(
        _entries(ref).map((e) => e.entry),
        periodRange(kind, now, weekStart: settings.weekStart),
        level: 1,
        now: now,
      );
      Duration usedBy(String project) => used.rows
          .where((r) => r.account == project)
          .fold(Duration.zero, (sum, r) => sum + r.duration);
      return [
        for (final b in budgets)
          BudgetProgress(b.project, usedBy(b.project), b.amount),
      ]..sort((a, b) => a.project.compareTo(b.project));
    });
