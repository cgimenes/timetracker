import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/account.dart';
import '../core/budget.dart';
import '../state/derived.dart';

/// Asks for a goal: account, hours and, for a repeating goal, the period.
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
  late final _account = TextEditingController(text: widget.old?.account ?? '');
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
    _account.dispose();
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
    return validateBudget(account: _account.text.trim(), hours: hours ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    // Recent accounts and their parents, best first.
    final accounts = <String>{
      for (final a in ref.watch(accountSuggestionsProvider))
        for (var l = 1; l <= accountDepth(a); l++) truncateAccount(a, l),
    }.take(6);
    final error = _error;
    final shown = _account.text.trim().isNotEmpty && _hours.text.isNotEmpty;

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
              key: const Key('budget-account'),
              controller: _account,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Account',
                hintText: 'work:project',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (accounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final p in accounts)
                      ActionChip(
                        label: Text(p),
                        onPressed: () => setState(() => _account.text = p),
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
                    _account.text.trim(),
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
