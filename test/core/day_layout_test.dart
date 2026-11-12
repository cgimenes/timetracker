import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/day_layout.dart';
import 'package:timetracker/core/timeclock.dart';

final day = DateTime(2026, 10, 30);
final now = DateTime(2026, 10, 30, 15);

Entry e(String account, DateTime start, DateTime? end) => Entry(
  inIndex: 0,
  outIndex: end == null ? null : 1,
  account: account,
  start: start,
  end: end,
  comment: null,
);

DateTime t(int h, [int m = 0, int d = 30]) => DateTime(2026, 10, d, h, m);

List<DayBlock<Entry>> layout(List<Entry> entries) =>
    layoutDay<Entry>(entries, (x) => x, day, now);

void main() {
  test('entries that do not overlap each take the full width', () {
    final blocks = layout([e('a', t(9), t(10)), e('b', t(10), t(11))]);
    expect(blocks.map((b) => (b.entry.account, b.column, b.columns)), [
      ('a', 0, 1),
      ('b', 0, 1),
    ]);
  });

  test('two overlapping entries share the width', () {
    final blocks = layout([e('a', t(9), t(11)), e('b', t(10), t(12))]);
    expect(blocks.map((b) => (b.entry.account, b.column, b.columns)), [
      ('a', 0, 2),
      ('b', 1, 2),
    ]);
  });

  test('a chain of overlaps is one cluster with the columns it needs', () {
    // a-b overlap, b-c overlap, a and c do not: c reuses a's column.
    final blocks = layout([
      e('a', t(9), t(10, 30)),
      e('b', t(10), t(12)),
      e('c', t(11), t(13)),
    ]);
    expect(blocks.map((b) => (b.entry.account, b.column, b.columns)), [
      ('a', 0, 2),
      ('b', 1, 2),
      ('c', 0, 2),
    ]);
  });

  test('a later cluster starts over with its own width', () {
    final blocks = layout([
      e('a', t(9), t(11)),
      e('b', t(9), t(11)),
      e('c', t(14), t(15)),
    ]);
    expect(blocks.map((b) => (b.entry.account, b.columns)), [
      ('a', 2),
      ('b', 2),
      ('c', 1),
    ]);
  });

  test('entries are clipped to the day', () {
    final blocks = layout([
      e('before', t(22, 0, 29), t(2)),
      e('after', t(23), t(1, 0, 31)),
    ]);
    expect(blocks[0].start, day);
    expect(blocks[0].end, t(2));
    expect(blocks[0].startMinute, 0);
    expect(blocks[1].start, t(23));
    expect(blocks[1].end, DateTime(2026, 10, 31));
    expect(blocks[1].endMinute, 24 * 60);
  });

  test('entries outside the day are left out', () {
    final blocks = layout([
      e('yesterday', t(9, 0, 29), t(10, 0, 29)),
      e('tomorrow', t(9, 0, 31), t(10, 0, 31)),
      e('midnight', t(0), t(0)),
    ]);
    expect(blocks, isEmpty);
  });

  test('a running entry ends at now', () {
    final blocks = layout([e('run', t(14), null)]);
    expect(blocks.single.end, now);
    expect(blocks.single.endMinute, 15 * 60);
  });

  test('a running entry on a past day runs to its end', () {
    final blocks = layoutDay<Entry>(
      [e('run', t(14, 0, 28), null)],
      (x) => x,
      DateTime(2026, 10, 28),
      now,
    );
    expect(blocks.single.endMinute, 24 * 60);
  });

  test('empty input', () {
    expect(layout([]), isEmpty);
  });
}
