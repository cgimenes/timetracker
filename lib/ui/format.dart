String _two(int n) => n.toString().padLeft(2, '0');

/// `3:05` for totals.
String formatHm(Duration d) => '${d.inHours}:${_two(d.inMinutes % 60)}';

/// `+3:05` or `-0:20`, for differences.
String formatSignedHm(Duration d) =>
    '${d.isNegative ? '-' : '+'}${formatHm(d.abs())}';

/// `8` or `7.5`, for chart axes.
String hoursLabel(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

/// `3:05:09` for timers that tick.
String formatHms(Duration d) =>
    '${d.inHours}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

String formatTimeOfDay(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String formatDate(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

String formatDateTime(DateTime t) => '${formatDate(t)} ${formatTimeOfDay(t)}';

/// `2026-10-30 09:00 to 10:30`, with the end date only when it differs.
String formatRange(DateTime start, DateTime end) {
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  return '${formatDateTime(start)} to '
      '${sameDay ? formatTimeOfDay(end) : formatDateTime(end)}';
}
