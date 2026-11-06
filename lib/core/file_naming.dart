enum SplitMethod { none, day, week, month }

const timeclockExtension = '.timeclock';

bool isTimeclockFile(String name) => name.endsWith(timeclockExtension);

/// Tokens: `{yyyy}`, `{MM}`, `{dd}`, `{ww}` (ISO week).
String defaultFileNameTemplate(SplitMethod split) => switch (split) {
  SplitMethod.none => 'time$timeclockExtension',
  SplitMethod.day => '{yyyy}-{MM}-{dd}$timeclockExtension',
  SplitMethod.week => '{yyyy}-W{ww}$timeclockExtension',
  SplitMethod.month => '{yyyy}-{MM}$timeclockExtension',
};

/// Returns an error message, or null when [template] gives a distinct file
/// name for every period of [split].
String? validateFileNameTemplate(String template, SplitMethod split) {
  if (template.isEmpty) return 'File name is empty';
  if (template.contains('/') || template.contains(r'\')) {
    return 'File name cannot contain path separators';
  }
  if (!template.endsWith(timeclockExtension)) {
    return 'File name must end with $timeclockExtension';
  }
  final required = switch (split) {
    SplitMethod.none => const <String>[],
    SplitMethod.day => const ['{yyyy}', '{MM}', '{dd}'],
    SplitMethod.week => const ['{yyyy}', '{ww}'],
    SplitMethod.month => const ['{yyyy}', '{MM}'],
  };
  for (final token in required) {
    if (!template.contains(token)) {
      return 'File name must contain $token to split by ${split.name}';
    }
  }
  return null;
}

/// File that holds entries that start on [date].
///
/// When the template uses `{ww}`, `{yyyy}` is the ISO week year, so the first
/// days of January that belong to the last week of the previous year (and the
/// reverse) land in the right file.
String fileNameFor(DateTime date, SplitMethod split, String template) {
  final iso = _isoWeek(date);
  final year = template.contains('{ww}') ? iso.year : date.year;
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return template
      .replaceAll('{yyyy}', p(year, 4))
      .replaceAll('{MM}', p(date.month))
      .replaceAll('{dd}', p(date.day))
      .replaceAll('{ww}', p(iso.week));
}

({int year, int week}) _isoWeek(DateTime date) {
  // The Thursday of the same week decides the ISO year. UTC avoids DST gaps.
  final thursday = DateTime.utc(
    date.year,
    date.month,
    date.day + (4 - date.weekday),
  );
  final jan1 = DateTime.utc(thursday.year);
  final week = thursday.difference(jan1).inDays ~/ 7 + 1;
  return (year: thursday.year, week: week);
}
