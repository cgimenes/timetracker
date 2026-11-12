import 'package:flutter/material.dart';

import '../theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/budget.dart';
import '../../core/file_naming.dart';
import '../../data/budget_repository.dart';
import '../../data/providers.dart';
import '../../settings/app_settings.dart';
import '../../state/budgets.dart';
import '../../state/clock.dart';
import '../../state/derived.dart';
import '../../state/entries.dart';
import '../choose_folder.dart';
import '../daily_goals_section.dart';
import '../format.dart';
import '../goal_dialog.dart';
import '../palette.dart';
import '../ui_actions.dart';

/// Every budget, grouped by the day, week or month it is for (the same slices
/// the files are split in). This is where budgets are configured.
class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFolder = ref.watch(treeUriProvider) != null;

    return Scaffold(
      body: SafeArea(
        child: !hasFolder
            ? const ChooseFolderPrompt()
            : RefreshIndicator(
                onRefresh: () => Future.wait([
                  ref.read(entriesProvider.notifier).reload(),
                  ref.read(budgetsProvider.notifier).reload(),
                ]),
                child: const _Groups(),
              ),
      ),
    );
  }
}

class _Groups extends ConsumerWidget {
  const _Groups();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(budgetsProvider);
    final split = ref.watch(settingsProvider.select((s) => s.split));
    final now = ref.watch(nowProvider);
    final progress = ref.watch(budgetProgressProvider);

    final byWindow = <BudgetWindow, List<BudgetProgress>>{};
    for (final p in progress) {
      byWindow.putIfAbsent(p.budget.window, () => []).add(p);
    }
    // The current slice is always there, to add a budget to it.
    final current = BudgetWindow.of(now, split);
    if (current != null) byWindow.putIfAbsent(current, () => []);

    final windows = byWindow.keys.toList()
      ..sort((a, b) {
        if (a.recurring != b.recurring) return a.recurring ? 1 : -1;
        if (a.recurring) return a.period.index.compareTo(b.period.index);
        final byFrom = b.from!.compareTo(a.from!);
        return byFrom != 0 ? byFrom : a.period.index.compareTo(b.period.index);
      });

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Card(
          margin: EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: DailyGoalsSection(),
          ),
        ),
        if (load.hasError && !load.hasValue)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not read $budgetFileName: ${load.error}'),
          ),
        for (var i = 0; i < windows.length; i++)
          _WindowCard(
            windows[i],
            (byWindow[windows[i]]!
              ..sort((a, b) => a.project.compareTo(b.project))),
            // Said once, in the first card.
            showNote: i == 0,
          ),
        // Without a file split there is no current period to add to.
        if (split == SplitMethod.none)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add-recurring'),
              icon: const Icon(Icons.add),
              label: const Text('Add goal'),
              onPressed: () => _edit(context, ref, window: null, old: null),
            ),
          ),
        // No card to hold the note.
        if (windows.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 16),
            child: Text(_savedNote),
          ),
      ],
    );
  }
}

const _savedNote =
    'Goals are saved in $budgetFileName as hledger periodic transactions '
    '(budgets), bounded to the period. hledger weeks start on Monday.';

/// Asks for a budget and saves it. [window] null means a recurring one, whose
/// period is asked too.
Future<void> _edit(
  BuildContext context,
  WidgetRef ref, {
  required BudgetWindow? window,
  required Budget? old,
}) async {
  final result = await showDialog<Budget>(
    context: context,
    builder: (_) => GoalDialog(window: window, old: old),
  );
  if (result == null || !context.mounted) return;
  await guard(context, () async {
    final notifier = ref.read(budgetsProvider.notifier);
    await notifier.set(result.project, result.window, result.amount);
    final moved =
        old != null &&
        (old.project != result.project || old.window != result.window);
    if (moved) await notifier.remove(old.project, old.window);
  });
}

class _WindowCard extends ConsumerWidget {
  const _WindowCard(this.window, this.rows, {this.showNote = false});

  final BudgetWindow window;
  final List<BudgetProgress> rows;

  /// Explains where goals are saved.
  final bool showNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = window.label;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      key: Key('window-$label'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(label, style: textTheme.titleMedium),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('No goals'),
              ),
            for (final p in rows) _BudgetTile(label, p),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton.icon(
                  key: Key('add-budget-$label'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add goal'),
                  onPressed: () =>
                      _edit(context, ref, window: window, old: null),
                ),
              ),
            ),
            if (showNote)
              Padding(
                key: const Key('goals-note'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(_savedNote, style: textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile(this.label, this.progress);

  final String label;
  final BudgetProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final b = progress.budget;
    final achieved = progress.achieved;

    return ListTile(
      key: Key('budget-$label-${b.project}'),
      contentPadding: trailingButtonTilePadding,
      onTap: () => _edit(context, ref, window: b.window, old: b),
      title: Row(
        children: [
          Expanded(child: Text(b.project)),
          if (achieved)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.check_circle,
                key: Key('goal-achieved-$label-${b.project}'),
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
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: LinearProgressIndicator(
          key: Key('goal-bar-$label-${b.project}'),
          value: progress.fraction,
          color: goalBarColor(achieved: achieved, brightness: brightness),
        ),
      ),
      trailing: IconButton(
        key: Key('budget-remove-$label-${b.project}'),
        tooltip: 'Remove',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmRemove(context, ref),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final b = progress.budget;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove goal?'),
        content: Text(
          '${b.project}, ${formatHours(b.amount)}h\n${b.window.label}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await guard(
      context,
      () => ref.read(budgetsProvider.notifier).remove(b.project, b.window),
    );
  }
}
