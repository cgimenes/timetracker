import 'account.dart';
import 'metrics.dart';

/// Period of a budget. Maps to the hledger periodic transaction keyword and
/// to the Metrics period it is measured against.
enum BudgetPeriod {
  daily(PeriodKind.today),
  weekly(PeriodKind.week),
  monthly(PeriodKind.month);

  const BudgetPeriod(this.kind);
  final PeriodKind kind;
}

/// Time allowed for one project (first account level) in one period.
class Budget {
  const Budget(this.project, this.period, this.amount);

  final String project;
  final BudgetPeriod period;
  final Duration amount;

  @override
  bool operator ==(Object other) =>
      other is Budget &&
      other.project == project &&
      other.period == period &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(project, period, amount);

  @override
  String toString() => '$project $period ${formatHours(amount)}h';
}

/// `40`, `1.5` or `0.25`: hours with at most two decimals, no trailing zeros.
String formatHours(Duration d) {
  final hours = (d.inSeconds / 3600 * 100).round() / 100;
  final text = hours.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Returns an error message, or null when the budget can be saved.
String? validateBudget({required String project, required double hours}) {
  final error = validateAccount(project);
  if (error != null) return error;
  if (project.contains(':')) return 'Budget is for a project, without ":"';
  if (!(hours > 0)) return 'Hours must be more than 0';
  if ((hours * 100 - (hours * 100).round()).abs() > 1e-6) {
    return 'Hours can have at most 2 decimals';
  }
  return null;
}

/// A line in a recognised budget block that could not be read.
class BudgetWarning {
  const BudgetWarning(this.line, this.text);

  /// 1-based.
  final int line;
  final String text;

  @override
  String toString() => 'line $line: cannot read "$text"';
}

final _header = RegExp(
  r'^~\s+(daily|weekly|monthly)\s*$',
  caseSensitive: false,
);
final _posting = RegExp(r'^\s+\(([^()]+)\)\s{2,}(\d+(?:\.\d+)?)\s*h\s*$');

class _Posting {
  _Posting(this.line, this.budget);
  int line;
  final Budget budget;
}

/// The text of `budget.journal`: hledger periodic transactions such as
///
///     ~ monthly
///         (work)    40h
///
/// Only `~ daily|weekly|monthly` blocks with `(project)  Nh` postings are
/// understood. Every other line is kept exactly as it is.
class BudgetDocument {
  BudgetDocument._(this._lines);

  factory BudgetDocument.parse(String text) =>
      BudgetDocument._(text.isEmpty ? <String>[] : text.split('\n'));

  /// Lines without the empty piece after a final newline.
  final List<String> _lines;

  List<_Posting> _postings() => _scan().$1;

  /// Postings plus the header line index of each period block (last wins).
  (List<_Posting>, Map<BudgetPeriod, int>, List<BudgetWarning>) _scan() {
    final postings = <_Posting>[];
    final headers = <BudgetPeriod, int>{};
    final warnings = <BudgetWarning>[];
    BudgetPeriod? current;
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final h = _header.firstMatch(line);
      if (h != null) {
        current = BudgetPeriod.values.byName(h.group(1)!.toLowerCase());
        headers[current] = i;
        continue;
      }
      final indented = line.startsWith(' ') || line.startsWith('\t');
      if (!indented || line.trim().isEmpty) {
        current = null;
        continue;
      }
      if (current == null || line.trim().startsWith(';')) continue;
      final m = _posting.firstMatch(line);
      if (m == null) {
        warnings.add(BudgetWarning(i + 1, line.trim()));
        continue;
      }
      final project = m.group(1)!;
      // Sub-accounts are valid hledger but not a first-iteration budget.
      if (project.contains(':')) continue;
      final hours = double.parse(m.group(2)!);
      postings.add(
        _Posting(
          i,
          Budget(project, current, Duration(seconds: (hours * 3600).round())),
        ),
      );
    }
    return (postings, headers, warnings);
  }

  List<Budget> get budgets => [for (final p in _postings()) p.budget];

  List<BudgetWarning> get warnings => _scan().$3;

  String _line(String project, Duration amount) =>
      '    ($project)    ${formatHours(amount)}h';

  /// Sets the budget of [project] for [period], replacing the old amount.
  void setBudget(String project, BudgetPeriod period, Duration amount) {
    final (postings, headers, _) = _scan();
    for (final p in postings) {
      if (p.budget.project == project && p.budget.period == period) {
        _lines[p.line] = _line(project, amount);
        return;
      }
    }
    final header = headers[period];
    if (header != null) {
      var at = header;
      while (at + 1 < _lines.length &&
          _lines[at + 1].trim().isNotEmpty &&
          (_lines[at + 1].startsWith(' ') || _lines[at + 1].startsWith('\t'))) {
        at++;
      }
      _lines.insert(at + 1, _line(project, amount));
      return;
    }
    if (_lines.isNotEmpty && _lines.last.isEmpty) _lines.removeLast();
    if (_lines.isNotEmpty) _lines.add('');
    _lines
      ..add('~ ${period.name}')
      ..add(_line(project, amount));
  }

  /// Removes the budget; its block goes too when nothing else is in it.
  void removeBudget(String project, BudgetPeriod period) {
    final (postings, headers, _) = _scan();
    final match = postings.where(
      (p) => p.budget.project == project && p.budget.period == period,
    );
    if (match.isEmpty) return;
    _lines.removeAt(match.first.line);
    final header = headers[period]!;
    final empty =
        header + 1 >= _lines.length ||
        !(_lines[header + 1].startsWith(' ') ||
            _lines[header + 1].startsWith('\t')) ||
        _lines[header + 1].trim().isEmpty;
    if (empty && header < match.first.line) {
      _lines.removeAt(header);
      if (header < _lines.length && _lines[header].isEmpty) {
        _lines.removeAt(header);
      }
    }
  }

  String serialize() {
    if (_lines.isEmpty) return '';
    final text = _lines.join('\n');
    return _lines.last.isEmpty ? text : '$text\n';
  }
}
