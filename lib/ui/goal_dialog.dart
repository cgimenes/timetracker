import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/account.dart';
import '../core/budget.dart';
import '../state/derived.dart';

/// Asks for a goal: project, hours and, for a repeating goal, the period.
/// Pops with the [Budget] to save, or null.
class GoalDialog extends ConsumerStatefulWidget {
  const GoalDialog({
    required this.window,
    required this.old,
    this.title,
    this.lockPeriod = false,
    super.key,
  });

  /// Shown instead of the default "Add goal, ..." title.
  final String? title;

  /// The period is fixed by [window]: do not ask for it.
  final bool lockPeriod;

  /// Where the budget applies. Null for a new recurring one.
  final BudgetWindow? window;
  final Budget? old;

  @override
  ConsumerState<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends ConsumerState<GoalDialog> {
  late final _project = TextEditingController(text: widget.old?.project ?? '');
  late final _hours = TextEditingController(
    text: widget.old == null ? '' : formatHours(widget.old!.amount),
  );
  late var _period = widget.window?.period ?? BudgetPeriod.monthly;

  /// The period only is a choice for budgets that repeat.
  bool get _asksPeriod =>
      !widget.lockPeriod && (widget.window == null || widget.window!.recurring);

  BudgetWindow get _window =>
      _asksPeriod ? BudgetWindow.recurring(_period) : widget.window!;

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
      title: Text(
        widget.title ??
            (widget.old == null
                ? 'Add goal, ${_window.label}'
                : 'Edit goal, ${_window.label}'),
      ),
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
            if (_asksPeriod) ...[
              const SizedBox(height: 12),
              SegmentedButton<BudgetPeriod>(
                key: const Key('budget-period'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: BudgetPeriod.daily, label: Text('Day')),
                  ButtonSegment(
                    value: BudgetPeriod.weekly,
                    label: Text('Week'),
                  ),
                  ButtonSegment(
                    value: BudgetPeriod.monthly,
                    label: Text('Month'),
                  ),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('budget-hours'),
              controller: _hours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Hours',
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
                    _window,
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
