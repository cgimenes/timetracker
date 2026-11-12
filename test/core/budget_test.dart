import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/budget.dart';

void main() {
  const text =
      '; my budgets\n'
      '~ monthly\n'
      '    (work)    40h\n'
      '    (personal)    10.5h\n'
      '\n'
      '~ weekly\n'
      '    (work)    10h\n';

  group('BudgetDocument.parse', () {
    test('reads budgets by period', () {
      final doc = BudgetDocument.parse(text);
      expect(doc.budgets, [
        const Budget('work', BudgetPeriod.monthly, Duration(hours: 40)),
        const Budget(
          'personal',
          BudgetPeriod.monthly,
          Duration(hours: 10, minutes: 30),
        ),
        const Budget('work', BudgetPeriod.weekly, Duration(hours: 10)),
      ]);
      expect(doc.warnings, isEmpty);
    });

    test('is case insensitive on the period and ignores other lines', () {
      final doc = BudgetDocument.parse(
        '~ Daily\n    (work)  2h\n'
        '~ every 2 weeks\n    (work)  9h\n'
        '2026-01-01 tx\n    expenses  1\n    cash\n',
      );
      expect(doc.budgets, [
        const Budget('work', BudgetPeriod.daily, Duration(hours: 2)),
      ]);
    });

    test('ignores sub-accounts and reports unreadable postings', () {
      final doc = BudgetDocument.parse(
        '~ monthly\n    (work:acme)    5h\n    (work)    lots\n    ; note\n',
      );
      expect(doc.budgets, isEmpty);
      expect(doc.warnings.map((w) => w.line), [3]);
    });

    test('empty text', () {
      expect(BudgetDocument.parse('').budgets, isEmpty);
      expect(BudgetDocument.parse('').serialize(), '');
    });
  });

  group('edits', () {
    test('parse and serialize keep the text byte for byte', () {
      expect(BudgetDocument.parse(text).serialize(), text);
      expect(BudgetDocument.parse('a\nb').serialize(), 'a\nb\n');
    });

    test('updates an existing amount in place', () {
      final doc = BudgetDocument.parse(text)
        ..setBudget('work', BudgetPeriod.monthly, const Duration(hours: 32));
      expect(doc.serialize(), text.replaceFirst('40h', '32h'));
    });

    test('adds to an existing block', () {
      final doc = BudgetDocument.parse(text)
        ..setBudget('study', BudgetPeriod.weekly, const Duration(minutes: 90));
      expect(
        doc.serialize(),
        text.replaceFirst(
          '    (work)    10h\n',
          '    (work)    10h\n    (study)    1.5h\n',
        ),
      );
    });

    test('adds a new block at the end', () {
      final doc = BudgetDocument.parse(text)
        ..setBudget('work', BudgetPeriod.daily, const Duration(hours: 8));
      expect(doc.serialize(), '$text\n~ daily\n    (work)    8h\n');
    });

    test('creates the text from nothing', () {
      final doc = BudgetDocument.parse('')
        ..setBudget('work', BudgetPeriod.monthly, const Duration(hours: 40));
      expect(doc.serialize(), '~ monthly\n    (work)    40h\n');
    });

    test('removes a posting and keeps its block when not empty', () {
      final doc = BudgetDocument.parse(text)
        ..removeBudget('personal', BudgetPeriod.monthly);
      expect(
        doc.serialize(),
        text.replaceFirst('    (personal)    10.5h\n', ''),
      );
    });

    test('removes an emptied block', () {
      final doc = BudgetDocument.parse(text)
        ..removeBudget('work', BudgetPeriod.weekly);
      expect(
        doc.serialize(),
        '; my budgets\n~ monthly\n    (work)    40h\n'
        '    (personal)    10.5h\n',
      );
    });

    test('removing something missing changes nothing', () {
      final doc = BudgetDocument.parse(text)
        ..removeBudget('x', BudgetPeriod.daily);
      expect(doc.serialize(), text);
    });
  });

  test('formatHours', () {
    expect(formatHours(const Duration(hours: 40)), '40');
    expect(formatHours(const Duration(minutes: 90)), '1.5');
    expect(formatHours(const Duration(minutes: 15)), '0.25');
    expect(formatHours(const Duration(hours: 10)), '10');
  });

  test('validateBudget', () {
    expect(validateBudget(project: 'work', hours: 40), isNull);
    expect(validateBudget(project: 'work', hours: 1.25), isNull);
    expect(validateBudget(project: '', hours: 1), isNotNull);
    expect(validateBudget(project: 'a:b', hours: 1), isNotNull);
    expect(validateBudget(project: 'work', hours: 0), isNotNull);
    expect(validateBudget(project: 'work', hours: -1), isNotNull);
    expect(validateBudget(project: 'work', hours: 1.234), isNotNull);
  });
}
