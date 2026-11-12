import 'account.dart';
import 'file_naming.dart';
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

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Where a budget applies: every [period] (recurring), or one day, week or
/// month, `[from, to)`, matching a slice of the files.
///
/// Written as the hledger rule header: `~ monthly` or
/// `~ monthly from 2026-10-01 to 2026-11-01`.
class BudgetWindow {
  const BudgetWindow(this.period, {this.from, this.to})
    : assert((from == null) == (to == null));

  /// Every day, week or month.
  const BudgetWindow.recurring(this.period) : from = null, to = null;

  /// The slice of [split] that holds [date]. Null when files are not split.
  static BudgetWindow? of(DateTime date, SplitMethod split) {
    final day = DateTime(date.year, date.month, date.day);
    switch (split) {
      case SplitMethod.none:
        return null;
      case SplitMethod.day:
        return BudgetWindow(
          BudgetPeriod.daily,
          from: day,
          to: DateTime(day.year, day.month, day.day + 1),
        );
      case SplitMethod.week:
        final monday = DateTime(
          day.year,
          day.month,
          day.day - (day.weekday - 1),
        );
        return BudgetWindow(
          BudgetPeriod.weekly,
          from: monday,
          to: DateTime(monday.year, monday.month, monday.day + 7),
        );
      case SplitMethod.month:
        return BudgetWindow(
          BudgetPeriod.monthly,
          from: DateTime(day.year, day.month),
          to: DateTime(day.year, day.month + 1),
        );
    }
  }

  final BudgetPeriod period;
  final DateTime? from;

  /// Exclusive.
  final DateTime? to;

  bool get recurring => from == null;

  bool contains(DateTime t) =>
      recurring || (!t.isBefore(from!) && t.isBefore(to!));

  /// The hledger header line.
  String get header => recurring
      ? '~ ${period.name}'
      : '~ ${period.name} from ${_ymd(from!)} to ${_ymd(to!)}';

  /// Short name for lists: `2026-W44`, `2026-10`, `2026-10-30`, or the dates
  /// when the window is not one of those.
  String get label {
    if (recurring) {
      return switch (period) {
        BudgetPeriod.daily => 'Every day',
        BudgetPeriod.weekly => 'Every week',
        BudgetPeriod.monthly => 'Every month',
      };
    }
    final f = from!;
    final t = to!;
    switch (period) {
      case BudgetPeriod.daily:
        if (t == DateTime(f.year, f.month, f.day + 1)) return _ymd(f);
      case BudgetPeriod.weekly:
        if (f.weekday == DateTime.monday &&
            t == DateTime(f.year, f.month, f.day + 7)) {
          final w = isoWeek(f);
          return '${w.year}-W${w.week.toString().padLeft(2, '0')}';
        }
      case BudgetPeriod.monthly:
        if (f.day == 1 && t == DateTime(f.year, f.month + 1)) {
          return _ymd(f).substring(0, 7);
        }
    }
    return '${_ymd(f)} to ${_ymd(t)}';
  }

  @override
  bool operator ==(Object other) =>
      other is BudgetWindow &&
      other.period == period &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(period, from, to);

  @override
  String toString() => header;
}

/// Time allowed for one project (first account level) in a [window].
class Budget {
  const Budget(this.project, this.window, this.amount);

  final String project;
  final BudgetWindow window;
  final Duration amount;

  BudgetPeriod get period => window.period;

  @override
  bool operator ==(Object other) =>
      other is Budget &&
      other.project == project &&
      other.window == window &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(project, window, amount);

  @override
  String toString() => '$project $window ${formatHours(amount)}h';
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
  r'^~\s+(daily|weekly|monthly)'
  r'(?:\s+from\s+(\d{4}-\d{2}-\d{2})\s+to\s+(\d{4}-\d{2}-\d{2}))?\s*$',
  caseSensitive: false,
);
final _posting = RegExp(r'^\s+\(([^()]+)\)\s{2,}(\d+(?:\.\d+)?)\s*h\s*$');

DateTime _date(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

class _Posting {
  _Posting(this.line, this.budget);
  final int line;
  final Budget budget;
}

/// The text of `budget.journal`: hledger periodic transactions such as
///
///     ~ monthly from 2026-10-01 to 2026-11-01
///         (work)    40h
///
/// A block without dates applies every day, week or month. Only
/// `~ daily|weekly|monthly` blocks (with optional `from` and `to` dates)
/// holding `(project)  Nh` postings are understood. Every other line is kept
/// exactly as it is.
class BudgetDocument {
  BudgetDocument._(this._lines);

  factory BudgetDocument.parse(String text) =>
      BudgetDocument._(text.isEmpty ? <String>[] : text.split('\n'));

  /// Lines, with an empty last piece after a final newline.
  final List<String> _lines;

  bool _indented(String line) => line.startsWith(' ') || line.startsWith('\t');

  /// Postings, the header line of each block (last one wins), and warnings.
  (List<_Posting>, Map<BudgetWindow, int>, List<BudgetWarning>) _scan() {
    final postings = <_Posting>[];
    final headers = <BudgetWindow, int>{};
    final warnings = <BudgetWarning>[];
    BudgetWindow? current;
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final h = _header.firstMatch(line);
      if (h != null) {
        final period = BudgetPeriod.values.byName(h.group(1)!.toLowerCase());
        current = h.group(2) == null
            ? BudgetWindow.recurring(period)
            : BudgetWindow(
                period,
                from: _date(h.group(2)!),
                to: _date(h.group(3)!),
              );
        headers[current] = i;
        continue;
      }
      if (!_indented(line) || line.trim().isEmpty) {
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

  List<Budget> get budgets => [for (final p in _scan().$1) p.budget];

  List<BudgetWarning> get warnings => _scan().$3;

  String _line(String project, Duration amount) =>
      '    ($project)    ${formatHours(amount)}h';

  /// Sets the budget of [project] in [window], replacing the old amount.
  void setBudget(String project, BudgetWindow window, Duration amount) {
    final (postings, headers, _) = _scan();
    for (final p in postings) {
      if (p.budget.project == project && p.budget.window == window) {
        _lines[p.line] = _line(project, amount);
        return;
      }
    }
    final header = headers[window];
    if (header != null) {
      var at = header;
      while (at + 1 < _lines.length &&
          _lines[at + 1].trim().isNotEmpty &&
          _indented(_lines[at + 1])) {
        at++;
      }
      _lines.insert(at + 1, _line(project, amount));
      return;
    }
    if (_lines.isNotEmpty && _lines.last.isEmpty) _lines.removeLast();
    if (_lines.isNotEmpty) _lines.add('');
    _lines
      ..add(window.header)
      ..add(_line(project, amount));
  }

  /// Removes the budget; its block goes too when nothing else is in it.
  void removeBudget(String project, BudgetWindow window) {
    final (postings, headers, _) = _scan();
    final match = postings.where(
      (p) => p.budget.project == project && p.budget.window == window,
    );
    if (match.isEmpty) return;
    final at = match.first.line;
    _lines.removeAt(at);
    final header = headers[window]!;
    final empty =
        header + 1 >= _lines.length ||
        !_indented(_lines[header + 1]) ||
        _lines[header + 1].trim().isEmpty;
    if (empty && header < at) {
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
