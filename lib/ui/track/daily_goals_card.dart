import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../state/derived.dart';
import '../goal_progress_row.dart';

/// The daily goals set in the Goals screen, each with the time done today:
/// yellow while in progress, green once reached. Hidden when none is set.
class DailyGoalsCard extends ConsumerWidget {
  const DailyGoalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(dailyGoalProgressProvider);
    if (goals.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('daily-goals'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily goals', style: Theme.of(context).textTheme.titleMedium),
            for (final g in goals)
              GoalProgressRow(PeriodKind.today, g, keyPrefix: 'track-'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
