import 'account.dart';

/// One line of a timeclock file.
sealed class TimeclockLine {
  const TimeclockLine();

  /// Exact text of the line, without line break.
  String get text;
}

/// A clock-in (`i`) or clock-out (`o`) line.
///
/// Lines read from a file keep their original [text] until replaced, so an
/// edit elsewhere in the file never reformats them.
final class ClockLine extends TimeclockLine {
  const ClockLine({
    required this.isIn,
    required this.time,
    required this.account,
    this.comment,
    this._raw,
  });

  final bool isIn;
  final DateTime time;

  /// Empty only for a clock-out that does not name its account.
  final String account;
  final String? comment;
  final String? _raw;

  @override
  String get text => _raw ?? format();

  /// Canonical form: `i 2026-10-30 09:00:00 work:acme:dev  comment`.
  String format() {
    final buf = StringBuffer(isIn ? 'i ' : 'o ')..write(formatTime(time));
    if (account.isNotEmpty) {
      buf
        ..write(' ')
        ..write(account);
    }
    if (comment != null && comment!.isNotEmpty) {
      buf
        ..write('  ')
        ..write(comment);
    }
    return buf.toString();
  }
}

/// Anything that is not a clock line: blank lines, comments, malformed lines.
final class OtherLine extends TimeclockLine {
  const OtherLine(this.text, {this.isMalformed = false});

  @override
  final String text;

  /// True when the line looks like a clock line but cannot be parsed.
  final bool isMalformed;
}

String formatTime(DateTime t) {
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${p(t.year, 4)}-${p(t.month)}-${p(t.day)} '
      '${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
}

final _clockLine = RegExp(
  r'^([io]) (\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(?: (.*))?$',
);

/// Parses one line; returns [OtherLine] for anything that is not a clock line.
TimeclockLine parseLine(String line) {
  // Keep a trailing \r in the stored text but ignore it for parsing.
  final body = line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
  final trimmed = body.trimLeft();
  if (trimmed.isEmpty ||
      trimmed.startsWith(';') ||
      trimmed.startsWith('#') ||
      trimmed.startsWith('*')) {
    return OtherLine(line);
  }

  final m = _clockLine.firstMatch(body);
  if (m == null) return OtherLine(line, isMalformed: true);

  final y = int.parse(m[2]!);
  final mo = int.parse(m[3]!);
  final d = int.parse(m[4]!);
  final h = int.parse(m[5]!);
  final mi = int.parse(m[6]!);
  final s = int.parse(m[7]!);
  final time = DateTime(y, mo, d, h, mi, s);
  final valid =
      time.year == y &&
      time.month == mo &&
      time.day == d &&
      time.hour == h &&
      time.minute == mi &&
      time.second == s;
  if (!valid) return OtherLine(line, isMalformed: true);

  final rest = (m[8] ?? '').trimLeft();
  final split = rest.indexOf('  ');
  final account = (split < 0 ? rest : rest.substring(0, split)).trim();
  final comment = split < 0 ? null : rest.substring(split).trim();
  final isIn = m[1] == 'i';
  if (isIn && account.isEmpty) return OtherLine(line, isMalformed: true);

  return ClockLine(
    isIn: isIn,
    time: time,
    account: account,
    comment: (comment == null || comment.isEmpty) ? null : comment,
    raw: line,
  );
}

/// A session: a clock-in with its clock-out, or a running entry without one.
class Entry {
  const Entry({
    required this.inIndex,
    required this.outIndex,
    required this.account,
    required this.start,
    required this.end,
    required this.comment,
  });

  /// Index of the clock-in line in the document.
  final int inIndex;

  /// Index of the clock-out line, null while running.
  final int? outIndex;
  final String account;
  final DateTime start;
  final DateTime? end;
  final String? comment;

  bool get isRunning => end == null;

  /// Elapsed time; running entries count up to [now]. Never negative.
  Duration duration(DateTime now) {
    final d = (end ?? now).difference(start);
    return d.isNegative ? Duration.zero : d;
  }
}

class TimeclockWarning {
  const TimeclockWarning(this.lineNumber, this.message);

  /// 1-based.
  final int lineNumber;
  final String message;

  @override
  String toString() => 'line $lineNumber: $message';
}

/// A timeclock file as a list of lines.
///
/// Immutable: every change returns a new document. Lines that are not touched
/// keep their exact text, so [serialize] only differs where a change was made.
class TimeclockDocument {
  TimeclockDocument._(this._lines, this._trailingNewline);

  factory TimeclockDocument.empty() => TimeclockDocument._(const [], true);

  factory TimeclockDocument.parse(String text) {
    if (text.isEmpty) return TimeclockDocument.empty();
    final parts = text.split('\n');
    final trailing = parts.last.isEmpty;
    if (trailing) parts.removeLast();
    return TimeclockDocument._(parts.map(parseLine).toList(), trailing);
  }

  final List<TimeclockLine> _lines;
  final bool _trailingNewline;

  List<TimeclockLine> get lines => List.unmodifiable(_lines);

  String serialize() {
    if (_lines.isEmpty) return '';
    return _lines.map((l) => l.text).join('\n') +
        (_trailingNewline ? '\n' : '');
  }

  late final _Pairing _pairing = _pair();

  /// Sessions in file order of their clock-in.
  List<Entry> get entries => _pairing.entries;

  List<Entry> get runningEntries =>
      entries.where((e) => e.isRunning).toList(growable: false);

  /// Malformed lines, clock-outs without a clock-in, and clock-outs that
  /// precede their clock-in.
  List<TimeclockWarning> get warnings => _pairing.warnings;

  /// The running entry a clock-out for [account] closes: the oldest one.
  Entry? oldestRunning(String account) {
    for (final e in entries) {
      if (e.isRunning && e.account == account) return e;
    }
    return null;
  }

  /// Pairs clock-outs with clock-ins.
  ///
  /// A clock-out naming an account closes the oldest running entry of that
  /// account. A clock-out without an account closes the most recent running
  /// entry (hledger behavior).
  _Pairing _pair() {
    final warnings = <TimeclockWarning>[];
    final open = <int>[]; // line indexes of running clock-ins, oldest first
    final outFor = <int, int>{}; // clock-in index -> clock-out index

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line is OtherLine) {
        if (line.isMalformed) {
          warnings.add(TimeclockWarning(i + 1, 'malformed line'));
        }
        continue;
      }
      line as ClockLine;
      if (line.isIn) {
        open.add(i);
        continue;
      }
      final at = line.account.isEmpty
          ? (open.isEmpty ? -1 : open.length - 1)
          : open.indexWhere(
              (j) => (_lines[j] as ClockLine).account == line.account,
            );
      if (at < 0) {
        warnings.add(TimeclockWarning(i + 1, 'clock-out without clock-in'));
        continue;
      }
      final inIndex = open.removeAt(at);
      outFor[inIndex] = i;
      if (line.time.isBefore((_lines[inIndex] as ClockLine).time)) {
        warnings.add(TimeclockWarning(i + 1, 'clock-out before clock-in'));
      }
    }

    final entries = <Entry>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line is! ClockLine || !line.isIn) continue;
      final outIndex = outFor[i];
      entries.add(
        Entry(
          inIndex: i,
          outIndex: outIndex,
          account: line.account,
          start: line.time,
          end: outIndex == null ? null : (_lines[outIndex] as ClockLine).time,
          comment: line.comment,
        ),
      );
    }
    return _Pairing(entries, warnings);
  }

  /// Appends a clock-in.
  TimeclockDocument startEntry(
    String account,
    DateTime time, {
    String? comment,
  }) {
    _check(account, comment);
    return _append(
      ClockLine(isIn: true, time: time, account: account, comment: comment),
    );
  }

  /// Appends a clock-in and, when [end] is given, its clock-out.
  TimeclockDocument addEntry(
    String account,
    DateTime start, {
    DateTime? end,
    String? comment,
  }) {
    _check(account, comment);
    if (end != null && !end.isAfter(start)) {
      throw ArgumentError('End must be after start');
    }
    return TimeclockDocument._([
      ..._lines,
      ClockLine(isIn: true, time: start, account: account, comment: comment),
      if (end != null) ClockLine(isIn: false, time: end, account: account),
    ], true);
  }

  /// Appends the clock-out of [entry], naming its account.
  TimeclockDocument stopEntry(Entry entry, DateTime time) {
    if (!entry.isRunning) throw ArgumentError('Entry is not running');
    if (!time.isAfter(entry.start)) {
      throw ArgumentError('End must be after start');
    }
    return _append(ClockLine(isIn: false, time: time, account: entry.account));
  }

  /// Replaces all fields of [entry]. Other lines are left untouched.
  ///
  /// A new [end] on a running entry appends the clock-out at the end of the
  /// file; a null [end] on a finished entry removes its clock-out.
  TimeclockDocument replaceEntry(
    Entry entry, {
    required String account,
    required DateTime start,
    DateTime? end,
    String? comment,
  }) {
    _check(account, comment);
    if (end != null && !end.isAfter(start)) {
      throw ArgumentError('End must be after start');
    }
    final lines = [..._lines];
    lines[entry.inIndex] = ClockLine(
      isIn: true,
      time: start,
      account: account,
      comment: comment,
    );

    final outIndex = entry.outIndex;
    final outLine = end == null
        ? null
        : ClockLine(isIn: false, time: end, account: account);
    if (outIndex != null) {
      if (outLine == null) {
        lines.removeAt(outIndex);
      } else {
        lines[outIndex] = outLine;
      }
    } else if (outLine != null) {
      lines.add(outLine);
    }
    return TimeclockDocument._(lines, true);
  }

  /// Removes the clock-in and clock-out of [entry].
  TimeclockDocument removeEntry(Entry entry) {
    final lines = [..._lines];
    final indexes = [entry.inIndex, ?entry.outIndex]..sort();
    for (final i in indexes.reversed) {
      lines.removeAt(i);
    }
    return TimeclockDocument._(lines, _trailingNewline);
  }

  TimeclockDocument _append(ClockLine line) =>
      TimeclockDocument._([..._lines, line], true);

  void _check(String account, String? comment) {
    final error = validateAccount(account) ?? validateComment(comment);
    if (error != null) throw ArgumentError(error);
  }
}

class _Pairing {
  const _Pairing(this.entries, this.warnings);
  final List<Entry> entries;
  final List<TimeclockWarning> warnings;
}
