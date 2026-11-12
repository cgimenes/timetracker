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

class AppSettings {
  const AppSettings({
    required this.split,
    required this.projects,
    required this.fileNameTemplate,
    required this.metricsLevel,
    required this.weekStart,
    this.budgetsEnabled = false,
    this.sideBarExpanded = false,
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
  }) => AppSettings(
    split: split ?? this.split,
    projects: projects ?? this.projects,
    fileNameTemplate: fileNameTemplate ?? this.fileNameTemplate,
    metricsLevel: metricsLevel ?? this.metricsLevel,
    weekStart: weekStart ?? this.weekStart,
    budgetsEnabled: budgetsEnabled ?? this.budgetsEnabled,
    sideBarExpanded: sideBarExpanded ?? this.sideBarExpanded,
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
}
