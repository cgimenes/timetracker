import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../state/derived.dart';
import '../format.dart';
import '../palette.dart';

/// Time per account for one period, with the goals that apply to it.
///
/// Grouped at the Metrics level, or at a fixed [level] when given (the Track
/// screen shows today by project, level 1). [keyPrefix] keeps the keys apart
/// when two cards for the same period are on screen.
class PeriodCard extends ConsumerWidget {
  const PeriodCard(
    this.kind,
    this.title, {
    this.level,
    this.keyPrefix = '',
    this.dailyGoals = false,
    super.key,
  });

  final PeriodKind kind;
  final String title;
  final int? level;
  final String keyPrefix;

  /// Show the daily goals of Settings instead of the goals of
  /// `budget.journal`.
  final bool dailyGoals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = level == null
        ? ref.watch(metricsProvider(kind))
        : ref.watch(levelMetricsProvider((kind, level!)));
    final budgets = dailyGoals
        ? ref.watch(dailyGoalProgressProvider)
        : ref.watch(metricsBudgetsProvider(kind));
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: textTheme.titleMedium)),
                Text(
                  formatHm(metrics.total),
                  key: Key('${keyPrefix}total-${kind.name}'),
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            if (metrics.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No time tracked'),
              ),
            for (final row in metrics.rows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(row.account)),
                    Text(formatHm(row.duration)),
                  ],
                ),
              ),
            if (budgets.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                dailyGoals ? 'Daily goals' : 'Goals',
                style: textTheme.titleSmall,
              ),
              for (final b in budgets) _BudgetRow(kind, b, keyPrefix),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow(this.kind, this.progress, this.keyPrefix);

  final PeriodKind kind;
  final BudgetProgress progress;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final achieved = progress.achieved;

    return Padding(
      key: Key('${keyPrefix}budget-${kind.name}-${progress.project}'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(progress.project)),
              if (achieved)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.check_circle,
                    key: Key(
                      '${keyPrefix}goal-achieved-${kind.name}-${progress.project}',
                    ),
                    size: 18,
                    color: goalAchievedTextColor(brightness),
                  ),
                ),
              Text(
                '${formatHm(progress.used)} / ${formatHm(progress.allowed)}',
                style: achieved
                    ? TextStyle(color: goalAchievedTextColor(brightness))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            key: Key('${keyPrefix}goal-bar-${kind.name}-${progress.project}'),
            value: progress.fraction,
            color: goalBarColor(achieved: achieved, brightness: brightness),
          ),
        ],
      ),
    );
  }
}
