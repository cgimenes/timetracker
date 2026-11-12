import 'timeclock.dart';

/// One entry drawn in the day column: the part of it inside the day, and the
/// slot it takes beside overlapping entries.
class DayBlock<T> {
  const DayBlock({
    required this.item,
    required this.entry,
    required this.start,
    required this.end,
    required this.column,
    required this.columns,
  });

  final T item;
  final Entry entry;

  /// Clipped to the day. A running entry ends at the current time.
  final DateTime start;
  final DateTime end;

  /// 0-based slot among the [columns] that overlapping entries share.
  final int column;
  final int columns;

  /// Minutes from midnight.
  double get startMinute => _minutes(start, start);
  double get endMinute => _minutes(start, end);

  double _minutes(DateTime from, DateTime t) {
    final midnight = DateTime(start.year, start.month, start.day);
    return t.difference(midnight).inSeconds / 60;
  }
}

/// Places the entries that touch [day] side by side where they overlap.
///
/// Each entry is clipped to the day. Entries that overlap, directly or through
/// a chain of others, share the width of the day column evenly; an entry
/// takes the first free slot to the left. Entries with no time inside the day
/// are left out. [entryOf] reads the entry out of each item.
List<DayBlock<T>> layoutDay<T>(
  Iterable<T> items,
  Entry Function(T item) entryOf,
  DateTime day,
  DateTime now,
) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);

  final clipped = <({T item, Entry entry, DateTime start, DateTime end})>[];
  for (final item in items) {
    final entry = entryOf(item);
    final rawEnd = entry.end ?? now;
    final start = entry.start.isBefore(dayStart) ? dayStart : entry.start;
    final end = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
    if (!end.isAfter(start)) continue;
    clipped.add((item: item, entry: entry, start: start, end: end));
  }
  clipped.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : b.end.compareTo(a.end);
  });

  final blocks = <DayBlock<T>>[];
  var cluster =
      <({T item, Entry entry, DateTime start, DateTime end, int col})>[];
  final columnEnds = <DateTime>[];
  DateTime? clusterEnd;

  void flush() {
    for (final c in cluster) {
      blocks.add(
        DayBlock(
          item: c.item,
          entry: c.entry,
          start: c.start,
          end: c.end,
          column: c.col,
          columns: columnEnds.length,
        ),
      );
    }
    cluster = [];
    columnEnds.clear();
    clusterEnd = null;
  }

  for (final c in clipped) {
    if (clusterEnd != null && !c.start.isBefore(clusterEnd!)) flush();
    var col = columnEnds.indexWhere((end) => !c.start.isBefore(end));
    if (col == -1) {
      col = columnEnds.length;
      columnEnds.add(c.end);
    } else {
      columnEnds[col] = c.end;
    }
    cluster.add((
      item: c.item,
      entry: c.entry,
      start: c.start,
      end: c.end,
      col: col,
    ));
    if (clusterEnd == null || c.end.isAfter(clusterEnd!)) clusterEnd = c.end;
  }
  flush();
  return blocks;
}
