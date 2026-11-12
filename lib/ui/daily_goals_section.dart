import 'package:flutter/material.dart';

import 'theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/budget.dart';
import '../settings/app_settings.dart';
import 'goal_dialog.dart';
import 'ui_actions.dart';

const _everyDay = BudgetWindow.recurring(BudgetPeriod.daily);

/// Daily goals in Settings: hours to reach every day, one per project. They
/// are saved in the app settings, not in `budget.journal`, and shown on the
/// Track screen.
class DailyGoalsSection extends ConsumerWidget {
  const DailyGoalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(settingsProvider.select((s) => s.dailyGoals));
    final projects = goals.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Daily goals',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Hours to reach every day for a project, shown on the Track '
            'screen. Kept in the app, not in the files.',
          ),
        ),
        if (projects.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('No daily goals'),
          ),
        for (final project in projects)
          ListTile(
            key: Key('daily-goal-$project'),
            contentPadding: trailingButtonTilePadding,
            title: Text(project),
            subtitle: Text('${formatHours(goals[project]!)}h a day'),
            onTap: () => _edit(
              context,
              ref,
              Budget(project, _everyDay, goals[project]!),
            ),
            trailing: IconButton(
              key: Key('daily-goal-remove-$project'),
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmRemove(context, ref, project),
            ),
          ),
        // Same button as "Add goal" in the cards below.
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              key: const Key('add-daily-goal'),
              icon: const Icon(Icons.add),
              label: const Text('Add daily goal'),
              onPressed: () => _edit(context, ref, null),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Budget? old) async {
    final result = await showDialog<Budget>(
      context: context,
      builder: (_) => GoalDialog(
        window: _everyDay,
        old: old,
        lockPeriod: true,
        title: old == null ? 'Add daily goal' : 'Edit daily goal',
      ),
    );
    if (result == null || !context.mounted) return;
    final settings = ref.read(settingsProvider.notifier);
    await guard(context, () async {
      await settings.setDailyGoal(result.project, result.amount);
      if (old != null && old.project != result.project) {
        await settings.removeDailyGoal(old.project);
      }
    });
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String project,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove daily goal?'),
        content: Text(project),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('daily-goal-remove-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(settingsProvider.notifier).removeDailyGoal(project);
  }
}
