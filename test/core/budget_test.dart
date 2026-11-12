import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/budget.dart';
import 'package:timetracker/core/file_naming.dart';

const _daily = BudgetWindow.recurring(BudgetPeriod.daily);
const _weekly = BudgetWindow.recurring(BudgetPeriod.weekly);
const _monthly = BudgetWindow.recurring(BudgetPeriod.monthly);

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
        const Budget('work', _monthly, Duration(hours: 40)),
        const Budget('personal', _monthly, Duration(hours: 10, minutes: 30)),
        const Budget('work', _weekly, Duration(hours: 10)),
      ]);
      expect(doc.warnings, isEmpty);
    });

    test('is case insensitive on the period and ignores other lines', () {
      final doc = BudgetDocument.parse(
        '~ Daily\n    (work)  2h\n'
        '~ every 2 weeks\n    (work)  9h\n'
        '2026-01-01 tx\n    expenses  1\n    cash\n',
      );
      expect(doc.budgets, [const Budget('work', _daily, Duration(hours: 2))]);
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
        ..setBudget('work', _monthly, const Duration(hours: 32));
      expect(doc.serialize(), text.replaceFirst('40h', '32h'));
    });

    test('adds to an existing block', () {
      final doc = BudgetDocument.parse(text)
        ..setBudget('study', _weekly, const Duration(minutes: 90));
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
        ..setBudget('work', _daily, const Duration(hours: 8));
      expect(doc.serialize(), '$text\n~ daily\n    (work)    8h\n');
    });

    test('creates the text from nothing', () {
      final doc = BudgetDocument.parse('')
        ..setBudget('work', _monthly, const Duration(hours: 40));
      expect(doc.serialize(), '~ monthly\n    (work)    40h\n');
    });

    test('removes a posting and keeps its block when not empty', () {
      final doc = BudgetDocument.parse(text)
        ..removeBudget('personal', _monthly);
      expect(
        doc.serialize(),
        text.replaceFirst('    (personal)    10.5h\n', ''),
      );
    });

    test('removes an emptied block', () {
      final doc = BudgetDocument.parse(text)..removeBudget('work', _weekly);
      expect(
        doc.serialize(),
        '; my budgets\n~ monthly\n    (work)    40h\n'
        '    (personal)    10.5h\n',
      );
    });

    test('removing something missing changes nothing', () {
      final doc = BudgetDocument.parse(text)..removeBudget('x', _daily);
      expect(doc.serialize(), text);
    });
  });

  group('windows', () {
    final oct = BudgetWindow.of(DateTime(2026, 10, 30), SplitMethod.month)!;
    final week = BudgetWindow.of(DateTime(2026, 10, 30), SplitMethod.week)!;
    final day = BudgetWindow.of(DateTime(2026, 10, 30), SplitMethod.day)!;

    test('slices follow the file split', () {
      expect(BudgetWindow.of(DateTime(2026, 10, 30), SplitMethod.none), isNull);
      expect(oct.header, '~ monthly from 2026-10-01 to 2026-11-01');
      expect(week.header, '~ weekly from 2026-10-26 to 2026-11-02');
      expect(day.header, '~ daily from 2026-10-30 to 2026-10-31');
      expect(
        [oct.label, week.label, day.label],
        ['2026-10', '2026-W44', '2026-10-30'],
      );
      expect(_weekly.label, 'Every week');
    });

    test('week at the turn of the year', () {
      final w = BudgetWindow.of(DateTime(2027, 1, 1), SplitMethod.week)!;
      expect(w.header, '~ weekly from 2026-12-28 to 2027-01-04');
      expect(w.label, '2026-W53');
    });

    test('contains is half open', () {
      expect(oct.contains(DateTime(2026, 10, 1)), isTrue);
      expect(oct.contains(DateTime(2026, 10, 31, 23, 59)), isTrue);
      expect(oct.contains(DateTime(2026, 11, 1)), isFalse);
      expect(oct.contains(DateTime(2026, 9, 30, 23, 59)), isFalse);
      expect(_monthly.contains(DateTime(2000)), isTrue);
    });

    test('dated blocks are read and kept apart from recurring ones', () {
      final doc = BudgetDocument.parse(
        '~ monthly\n    (work)    40h\n\n'
        '${oct.header}\n    (work)    30h\n    (personal)    5h\n',
      );
      expect(doc.budgets, [
        const Budget('work', _monthly, Duration(hours: 40)),
        Budget('work', oct, const Duration(hours: 30)),
        Budget('personal', oct, const Duration(hours: 5)),
      ]);
    });

    test('set adds a dated block, then updates and removes inside it', () {
      final doc = BudgetDocument.parse('')
        ..setBudget('work', oct, const Duration(hours: 30))
        ..setBudget('work', week, const Duration(hours: 8));
      expect(
        doc.serialize(),
        '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    30h\n\n'
        '~ weekly from 2026-10-26 to 2026-11-02\n    (work)    8h\n',
      );
      doc
        ..setBudget('work', oct, const Duration(hours: 32))
        ..removeBudget('work', week);
      expect(
        doc.serialize(),
        '~ monthly from 2026-10-01 to 2026-11-01\n    (work)    32h\n',
      );
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
