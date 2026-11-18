import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/budget.dart';
import '../data/budget_repository.dart';
import '../data/providers.dart';

/// The budgets in `budget.journal`, plus the actions that change it. Same
/// idea as the entries: the file is the only source of truth, so it is read
/// again after every action.
final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, BudgetLoad>(
  BudgetsNotifier.new,
);

class BudgetsNotifier extends AsyncNotifier<BudgetLoad> {
  @override
  Future<BudgetLoad> build() => ref.watch(budgetRepositoryProvider).load();

  BudgetRepository get _repo => ref.read(budgetRepositoryProvider);

  Future<void> reload() async {
    try {
      state = AsyncData(await _repo.load());
    } catch (e, st) {
      state = AsyncError<BudgetLoad>(e, st);
    }
  }

  /// Reloads only when the file changed since the last load.
  Future<void> reloadIfChanged() async {
    final current = state.value;
    if (current == null || await _repo.hasChanged(current)) await reload();
  }

  Future<void> set(String account, BudgetWindow window, Duration amount) =>
      _change((repo) => repo.set(account, window, amount));

  Future<void> remove(String account, BudgetWindow window) =>
      _change((repo) => repo.remove(account, window));

  Future<int> rename(String from, String to) async {
    var count = 0;
    await _change((repo) async => count = await repo.rename(from, to));
    return count;
  }

  Future<void> _change(
    Future<void> Function(BudgetRepository repo) action,
  ) async {
    try {
      await action(_repo);
    } finally {
      await reload();
    }
  }
}
