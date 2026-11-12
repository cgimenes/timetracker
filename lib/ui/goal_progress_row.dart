import 'package:flutter/material.dart';

import '../core/metrics.dart';
import '../state/derived.dart';
import 'format.dart';
import 'palette.dart';

/// A goal with the time done so far: project, done / goal, and a progress
/// bar that is yellow while in progress and green once achieved.
class GoalProgressRow extends StatelessWidget {
  const GoalProgressRow(
    this.kind,
    this.progress, {
    this.keyPrefix = '',
    super.key,
  });

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
