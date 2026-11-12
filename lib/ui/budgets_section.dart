import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/account.dart';
import '../core/budget.dart';
import '../data/budget_repository.dart';
import '../state/budgets.dart';
import '../state/derived.dart';
import 'ui_actions.dart';

/// Budgets in Settings: list, add, edit and remove. Saved in
/// `budget.journal` as hledger periodic transactions.
class BudgetsSection extends ConsumerWidget {
  const BudgetsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(budgetsProvider);
    final budgets = [...?load.value?.budgets]
      ..sort((a, b) {
        final byPeriod = a.period.index.compareTo(b.period.index);
        return byPeriod != 0 ? byPeriod : a.project.compareTo(b.project);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Budgets', style: Theme.of(context).textTheme.titleSmall),
        ),
        if (load.hasError && !load.hasValue)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Could not read $budgetFileName: ${load.error}'),
          ),
        if (load.hasValue && budgets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No budgets'),
          ),
        for (final b in budgets)
          ListTile(
            key: Key('budget-${b.period.name}-${b.project}'),
            title: Text(b.project),
            subtitle: Text('${b.period.name}, ${formatHours(b.amount)}h'),
            onTap: () => _edit(context, ref, b),
            trailing: IconButton(
              key: Key('budget-remove-${b.period.name}-${b.project}'),
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => guard(
                context,
                () => ref
                    .read(budgetsProvider.notifier)
                    .remove(b.project, b.period),
              ),
            ),
          ),
        ListTile(
          key: const Key('add-budget'),
          leading: const Icon(Icons.add),
          title: const Text('Add budget'),
          onTap: () => _edit(context, ref, null),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Saved in $budgetFileName as hledger periodic transactions. '
            'hledger weeks start on Monday.',
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Budget? old) async {
    final result = await showDialog<Budget>(
      context: context,
      builder: (_) => _BudgetDialog(old),
    );
    if (result == null || !context.mounted) return;
    await guard(context, () async {
      final notifier = ref.read(budgetsProvider.notifier);
      final moved =
          old != null &&
          (old.project != result.project || old.period != result.period);
      await notifier.set(result.project, result.period, result.amount);
      if (moved) await notifier.remove(old.project, old.period);
    });
  }
}

class _BudgetDialog extends ConsumerStatefulWidget {
  const _BudgetDialog(this.old);

  final Budget? old;

  @override
  ConsumerState<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends ConsumerState<_BudgetDialog> {
  late final _project = TextEditingController(text: widget.old?.project ?? '');
  late final _hours = TextEditingController(
    text: widget.old == null ? '' : formatHours(widget.old!.amount),
  );
  late var _period = widget.old?.period ?? BudgetPeriod.monthly;

  @override
  void dispose() {
    _project.dispose();
    _hours.dispose();
    super.dispose();
  }

  double? get _hoursValue =>
      double.tryParse(_hours.text.trim().replaceAll(',', '.'));

  String? get _error {
    final hours = _hoursValue;
    if (_hours.text.trim().isNotEmpty && hours == null) {
      return 'Hours is not a number';
    }
    return validateBudget(project: _project.text.trim(), hours: hours ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final projects = <String>{
      for (final a in ref.watch(accountSuggestionsProvider)) projectOf(a),
    }.take(6);
    final error = _error;
    final shown = _project.text.trim().isNotEmpty && _hours.text.isNotEmpty;

    return AlertDialog(
      title: Text(widget.old == null ? 'Add budget' : 'Edit budget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('budget-project'),
              controller: _project,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Project',
                hintText: 'work',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (projects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final p in projects)
                      ActionChip(
                        label: Text(p),
                        onPressed: () => setState(() => _project.text = p),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SegmentedButton<BudgetPeriod>(
              key: const Key('budget-period'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: BudgetPeriod.daily, label: Text('Day')),
                ButtonSegment(value: BudgetPeriod.weekly, label: Text('Week')),
                ButtonSegment(
                  value: BudgetPeriod.monthly,
                  label: Text('Month'),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('budget-hours'),
              controller: _hours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Hours',
                hintText: '40',
                border: const OutlineInputBorder(),
                errorText: shown ? error : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('budget-save'),
          onPressed: error == null
              ? () => Navigator.pop(
                  context,
                  Budget(
                    _project.text.trim(),
                    _period,
                    Duration(seconds: (_hoursValue! * 3600).round()),
                  ),
                )
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
