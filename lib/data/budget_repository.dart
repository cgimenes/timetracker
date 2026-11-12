import '../core/budget.dart';
import 'timeclock_storage.dart';

/// File in the timeclock directory that holds the budgets. Written as hledger
/// periodic transactions, so
/// `hledger -f budget.journal -f '*.timeclock' bal --budget` reads it.
const budgetFileName = 'budget.journal';

/// The budgets as read at one moment.
class BudgetLoad {
  const BudgetLoad({
    required this.file,
    required this.budgets,
    required this.warnings,
  });

  /// State of the file when read, null when it does not exist.
  final StoredFile? file;
  final List<Budget> budgets;
  final List<BudgetWarning> warnings;
}

/// Reads and writes [budgetFileName]. Like the entries, nothing is cached:
/// every change re-reads the file first.
class BudgetRepository {
  const BudgetRepository(this._storage);

  final TimeclockStorage _storage;

  Future<StoredFile?> _stat() async {
    for (final f in await _storage.list()) {
      if (f.name == budgetFileName) return f;
    }
    return null;
  }

  Future<BudgetLoad> load() async {
    final file = await _stat();
    final text = file == null ? null : await _storage.read(budgetFileName);
    final doc = BudgetDocument.parse(text ?? '');
    return BudgetLoad(
      file: text == null ? null : file,
      budgets: doc.budgets,
      warnings: doc.warnings,
    );
  }

  /// True when the file was added, removed or modified since [previous].
  Future<bool> hasChanged(BudgetLoad previous) async =>
      (await _stat()) != previous.file;

  Future<void> set(String project, BudgetWindow window, Duration amount) =>
      _update((doc) => doc.setBudget(project, window, amount));

  Future<void> remove(String project, BudgetWindow window) =>
      _update((doc) => doc.removeBudget(project, window));

  Future<void> _update(void Function(BudgetDocument doc) change) async {
    final old = await _storage.read(budgetFileName) ?? '';
    final doc = BudgetDocument.parse(old);
    change(doc);
    final next = doc.serialize();
    if (next == old) return;
    await _storage.write(budgetFileName, next);
  }
}
