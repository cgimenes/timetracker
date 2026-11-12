enum SplitMethod { none, day, week, month }

/// How projects (first account level) are told apart on disk.
enum ProjectSplit {
  /// All projects share the same files.
  none,

  /// One file per project: `work-2026-10.timeclock`.
  fileName,

  /// One folder per project: `work/2026-10.timeclock`.
  folder,
}

const timeclockExtension = '.timeclock';

const projectToken = '{project}';

bool isTimeclockFile(String name) => name.endsWith(timeclockExtension);

/// Tokens: `{yyyy}`, `{MM}`, `{dd}`, `{ww}` (ISO week), and `{project}` (first
/// level of the account) when files are also split by project.
String defaultFileNameTemplate(SplitMethod split, {bool byProject = false}) {
  final period = switch (split) {
    SplitMethod.none => '',
    SplitMethod.day => '{yyyy}-{MM}-{dd}',
    SplitMethod.week => '{yyyy}-W{ww}',
    SplitMethod.month => '{yyyy}-{MM}',
  };
  if (byProject) {
    return period.isEmpty
        ? '$projectToken$timeclockExtension'
        : '$projectToken-$period$timeclockExtension';
  }
  return period.isEmpty
      ? 'time$timeclockExtension'
      : '$period$timeclockExtension';
}

/// Returns an error message, or null when [template] gives a distinct file
/// name for every period of [split] (and for every project, with [byProject]).
String? validateFileNameTemplate(
  String template,
  SplitMethod split, {
  bool byProject = false,
}) {
  if (template.isEmpty) return 'File name is empty';
  if (template.contains('/') || template.contains(r'\')) {
    return 'File name cannot contain path separators';
  }
  if (!template.endsWith(timeclockExtension)) {
    return 'File name must end with $timeclockExtension';
  }
  final required = [
    ...switch (split) {
      SplitMethod.none => const <String>[],
      SplitMethod.day => const ['{yyyy}', '{MM}', '{dd}'],
      SplitMethod.week => const ['{yyyy}', '{ww}'],
      SplitMethod.month => const ['{yyyy}', '{MM}'],
    },
  ];
  for (final token in required) {
    if (!template.contains(token)) {
      return 'File name must contain $token to split by ${split.name}';
    }
  }
  if (byProject && !template.contains(projectToken)) {
    return 'File name must contain $projectToken to split projects by file name';
  }
  if (!byProject && template.contains(projectToken)) {
    return '$projectToken needs Projects set to "File name"';
  }
  return null;
}

/// File that holds entries that start on [date], for the account whose first
/// level is [project].
///
/// When the template uses `{ww}`, `{yyyy}` is the ISO week year, so the first
/// days of January that belong to the last week of the previous year (and the
/// reverse) land in the right file.
///
/// [project] only matters when the template has `{project}`. Characters that
/// are not safe in a file name are replaced by `_`.
String fileNameFor(
  DateTime date,
  SplitMethod split,
  String template, {
  String? project,
}) {
  final iso = isoWeek(date);
  final year = template.contains('{ww}') ? iso.year : date.year;
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return template
      .replaceAll(projectToken, safeFileNamePart(project ?? ''))
      .replaceAll('{yyyy}', p(year, 4))
      .replaceAll('{MM}', p(date.month))
      .replaceAll('{dd}', p(date.day))
      .replaceAll('{ww}', p(iso.week));
}

/// [text] with the characters that file systems or the document provider
/// reject replaced by `_`, and no leading dot (which would hide the file).
String safeFileNamePart(String text) => text
    .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
    .replaceFirst(RegExp(r'^\.+'), '_')
    .trim();

/// ISO 8601 week of [date]; the year can differ from the calendar year.
({int year, int week}) isoWeek(DateTime date) {
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
