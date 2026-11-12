import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/budget.dart';
import 'package:timetracker/data/budget_repository.dart';

import '../support/memory_storage.dart';

void main() {
  late MemoryStorage storage;
  late BudgetRepository repo;

  setUp(() {
    storage = MemoryStorage();
    repo = BudgetRepository(storage);
  });

  test('no file means no budgets', () async {
    final load = await repo.load();
    expect(load.file, isNull);
    expect(load.budgets, isEmpty);
  });

  test('set creates the file and load reads it back', () async {
    await repo.set('work', BudgetPeriod.monthly, const Duration(hours: 40));
    expect(storage.text(budgetFileName), '~ monthly\n    (work)    40h\n');
    final load = await repo.load();
    expect(load.budgets, [
      const Budget('work', BudgetPeriod.monthly, Duration(hours: 40)),
    ]);
  });

  test('keeps lines it does not understand', () async {
    const text = '; mine\n2026-01-01 tx\n    a  1\n    b\n';
    storage.externalWrite(budgetFileName, text);
    await repo.set('work', BudgetPeriod.daily, const Duration(hours: 8));
    expect(storage.text(budgetFileName), '$text\n~ daily\n    (work)    8h\n');
  });

  test('remove deletes the budget', () async {
    await repo.set('work', BudgetPeriod.monthly, const Duration(hours: 40));
    await repo.remove('work', BudgetPeriod.monthly);
    expect((await repo.load()).budgets, isEmpty);
  });

  test('hasChanged sees the file appear, change and vanish', () async {
    final before = await repo.load();
    expect(await repo.hasChanged(before), isFalse);

    storage.externalWrite(budgetFileName, '~ weekly\n    (a)  1h\n');
    expect(await repo.hasChanged(before), isTrue);

    final loaded = await repo.load();
    expect(await repo.hasChanged(loaded), isFalse);
    storage.externalWrite(budgetFileName, '~ weekly\n    (a)  2h\n');
    expect(await repo.hasChanged(loaded), isTrue);

    storage.externalDelete(budgetFileName);
    expect(await repo.hasChanged(loaded), isTrue);
  });

  test('budget file is not read as entries', () async {
    // isTimeclockFile only matches *.timeclock.
    storage.externalWrite(budgetFileName, '~ weekly\n    (a)  1h\n');
    final names = (await storage.list()).map((f) => f.name);
    expect(names, contains(budgetFileName));
  });
}
