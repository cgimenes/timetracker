import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/file_naming.dart';
import '../core/metrics.dart';
import '../data/providers.dart';
import '../data/timeclock_repository.dart';

const _splitKey = 'split';
const _byProjectKey = 'splitByProject'; // before projectSplit existed
const _projectSplitKey = 'projectSplit';
const _templateKey = 'fileNameTemplate';
const _levelKey = 'metricsLevel';
const _weekStartKey = 'weekStart';
const _budgetsKey = 'budgetsEnabled';
const _sideBarKey = 'sideBarExpanded';
const _calendarLevelKey = 'calendarLevel';
const _hourHeightKey = 'calendarHourHeight';
const _dailyGoalsKey = 'dailyGoals';

/// Height of one hour in the Calendar, in logical pixels: the zoom range.
const minHourHeight = 28.0;
const maxHourHeight = 168.0;
const defaultHourHeight = 56.0;

class AppSettings {
  const AppSettings({
    required this.split,
    required this.projects,
    required this.fileNameTemplate,
    required this.metricsLevel,
    required this.weekStart,
    this.budgetsEnabled = false,
    this.sideBarExpanded = false,
    this.calendarLevel = 1,
    this.calendarHourHeight = defaultHourHeight,
    this.dailyGoals = const {},
  });

  factory AppSettings.defaults() => AppSettings(
    split: SplitMethod.month,
    projects: ProjectSplit.none,
    fileNameTemplate: defaultFileNameTemplate(SplitMethod.month),
    metricsLevel: 1,
    weekStart: WeekStart.monday,
  );

  final SplitMethod split;

  /// How projects (first account level) are told apart, on top of [split].
  final ProjectSplit projects;

  /// Project in the file name: the template then has `{project}`.
  bool get splitByProject => projects == ProjectSplit.fileName;
  final String fileNameTemplate;

  /// Account depth used to group the Metrics totals, at least 1.
  final int metricsLevel;
  final WeekStart weekStart;

  /// Shows the Budgets tab and the budgets in Metrics.
  final bool budgetsEnabled;

  /// The side bar of wide screens shows labels, not only icons.
  final bool sideBarExpanded;

  /// Account level (1 to 3) the Calendar colors entries by.
  final int calendarLevel;

  /// Zoom of the Calendar: height of one hour, between [minHourHeight] and
  /// [maxHourHeight].
  final double calendarHourHeight;

  /// Time to reach every day, per project. Saved here, not in
  /// `budget.journal`, and shown on the Track screen.
  final Map<String, Duration> dailyGoals;

  FileSettings get fileSettings => FileSettings(
    split,
    fileNameTemplate,
    splitByProject: splitByProject,
    projectFolders: projects == ProjectSplit.folder,
  );

  AppSettings copyWith({
    SplitMethod? split,
    ProjectSplit? projects,
    String? fileNameTemplate,
    int? metricsLevel,
    WeekStart? weekStart,
    bool? budgetsEnabled,
    bool? sideBarExpanded,
    int? calendarLevel,
    double? calendarHourHeight,
    Map<String, Duration>? dailyGoals,
  }) => AppSettings(
    split: split ?? this.split,
    projects: projects ?? this.projects,
    fileNameTemplate: fileNameTemplate ?? this.fileNameTemplate,
    metricsLevel: metricsLevel ?? this.metricsLevel,
    weekStart: weekStart ?? this.weekStart,
    budgetsEnabled: budgetsEnabled ?? this.budgetsEnabled,
    sideBarExpanded: sideBarExpanded ?? this.sideBarExpanded,
    calendarLevel: calendarLevel ?? this.calendarLevel,
    calendarHourHeight: calendarHourHeight ?? this.calendarHourHeight,
    dailyGoals: dailyGoals ?? this.dailyGoals,
  );
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final defaults = AppSettings.defaults();

    final split =
        SplitMethod.values.asNameMap()[prefs.getString(_splitKey)] ??
        defaults.split;
    final projects =
        ProjectSplit.values.asNameMap()[prefs.getString(_projectSplitKey)] ??
        (prefs.getBool(_byProjectKey) == true
            ? ProjectSplit.fileName
            : defaults.projects);
    final byProject = projects == ProjectSplit.fileName;
    var template = prefs.getString(_templateKey);
    if (template == null ||
        validateFileNameTemplate(template, split, byProject: byProject) !=
            null) {
      template = defaultFileNameTemplate(split, byProject: byProject);
    }
    final level = prefs.getInt(_levelKey);
    return AppSettings(
      split: split,
      projects: projects,
      fileNameTemplate: template,
      metricsLevel: level != null && level >= 1 ? level : defaults.metricsLevel,
      weekStart:
          WeekStart.values.asNameMap()[prefs.getString(_weekStartKey)] ??
          defaults.weekStart,
      budgetsEnabled: prefs.getBool(_budgetsKey) ?? false,
      sideBarExpanded: prefs.getBool(_sideBarKey) ?? false,
      calendarLevel: switch (prefs.getInt(_calendarLevelKey)) {
        2 => 2,
        3 => 3,
        _ => 1,
      },
      calendarHourHeight: (prefs.getDouble(_hourHeightKey) ?? defaultHourHeight)
          .clamp(minHourHeight, maxHourHeight),
      dailyGoals: _readDailyGoals(prefs.getString(_dailyGoalsKey)),
    );
  }

  /// Changes how entries are spread over files. Files already written are not
  /// touched.
  ///
  /// A template that still is the default for the old choice follows the new
  /// one. A custom one is kept when it works for the new choice, otherwise it
  /// goes back to the default.
  Future<void> setSplit(SplitMethod split) =>
      _setSplitting(split, state.projects);

  /// How projects (first level of the account) are told apart. Same rule for
  /// the template as [setSplit].
  Future<void> setProjects(ProjectSplit projects) =>
      _setSplitting(state.split, projects);

  /// Shortcut for [setProjects]: project in the file name, or together.
  Future<void> setSplitByProject(bool byProject) =>
      setProjects(byProject ? ProjectSplit.fileName : ProjectSplit.none);

  Future<void> _setSplitting(SplitMethod split, ProjectSplit projects) async {
    final old = state;
    final byProject = projects == ProjectSplit.fileName;
    final followsDefault =
        old.fileNameTemplate ==
        defaultFileNameTemplate(old.split, byProject: old.splitByProject);
    final keepsWorking =
        validateFileNameTemplate(
          old.fileNameTemplate,
          split,
          byProject: byProject,
        ) ==
        null;
    final template = (!followsDefault && keepsWorking)
        ? old.fileNameTemplate
        : defaultFileNameTemplate(split, byProject: byProject);

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_splitKey, split.name);
    await prefs.setString(_projectSplitKey, projects.name);
    await prefs.setString(_templateKey, template);
    state = old.copyWith(
      split: split,
      projects: projects,
      fileNameTemplate: template,
    );
  }

  /// Returns an error message, or null when the template was saved.
  Future<String?> setFileNameTemplate(String template) async {
    final error = validateFileNameTemplate(
      template,
      state.split,
      byProject: state.splitByProject,
    );
    if (error != null) return error;
    await ref.read(sharedPreferencesProvider).setString(_templateKey, template);
    state = state.copyWith(fileNameTemplate: template);
    return null;
  }

  /// Returns an error message, or null when the level was saved.
  Future<String?> setMetricsLevel(int level) async {
    if (level < 1) return 'Level must be at least 1';
    await ref.read(sharedPreferencesProvider).setInt(_levelKey, level);
    state = state.copyWith(metricsLevel: level);
    return null;
  }

  Future<void> setWeekStart(WeekStart weekStart) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_weekStartKey, weekStart.name);
    state = state.copyWith(weekStart: weekStart);
  }

  Future<void> setBudgetsEnabled(bool enabled) async {
    await ref.read(sharedPreferencesProvider).setBool(_budgetsKey, enabled);
    state = state.copyWith(budgetsEnabled: enabled);
  }

  Future<void> setSideBarExpanded(bool expanded) async {
    await ref.read(sharedPreferencesProvider).setBool(_sideBarKey, expanded);
    state = state.copyWith(sideBarExpanded: expanded);
  }

  /// 1 to 3: how many account levels name a color in the Calendar.
  Future<void> setCalendarLevel(int level) async {
    final value = level.clamp(1, 3);
    await ref.read(sharedPreferencesProvider).setInt(_calendarLevelKey, value);
    state = state.copyWith(calendarLevel: value);
  }

  /// Zooms the Calendar. Kept between [minHourHeight] and [maxHourHeight].
  Future<void> setCalendarHourHeight(double height) async {
    final value = height.clamp(minHourHeight, maxHourHeight);
    if (value == state.calendarHourHeight) return;
    state = state.copyWith(calendarHourHeight: value);
    await ref.read(sharedPreferencesProvider).setDouble(_hourHeightKey, value);
  }

  /// Sets the daily goal of [project], in minutes of precision.
  Future<void> setDailyGoal(String project, Duration amount) =>
      _saveDailyGoals({...state.dailyGoals, project: amount});

  Future<void> removeDailyGoal(String project) =>
      _saveDailyGoals({...state.dailyGoals}..remove(project));

  Future<void> _saveDailyGoals(Map<String, Duration> goals) async {
    state = state.copyWith(dailyGoals: Map.unmodifiable(goals));
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _dailyGoalsKey,
          jsonEncode({for (final e in goals.entries) e.key: e.value.inSeconds}),
        );
  }
}

/// Daily goals as saved: JSON of project to seconds. Anything unreadable is
/// dropped.
Map<String, Duration> _readDailyGoals(String? json) {
  if (json == null) return const {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const {};
    return Map.unmodifiable({
      for (final e in decoded.entries)
        if (e.key is String && e.value is int && (e.value as int) > 0)
          e.key as String: Duration(seconds: e.value as int),
    });
  } on FormatException {
    return const {};
  }
}
