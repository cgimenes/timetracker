import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/file_naming.dart';
import '../core/metrics.dart';
import '../data/providers.dart';
import '../data/timeclock_repository.dart';

const _splitKey = 'split';
const _byProjectKey = 'splitByProject';
const _templateKey = 'fileNameTemplate';
const _levelKey = 'metricsLevel';
const _weekStartKey = 'weekStart';

class AppSettings {
  const AppSettings({
    required this.split,
    required this.splitByProject,
    required this.fileNameTemplate,
    required this.metricsLevel,
    required this.weekStart,
  });

  factory AppSettings.defaults() => AppSettings(
    split: SplitMethod.month,
    splitByProject: false,
    fileNameTemplate: defaultFileNameTemplate(SplitMethod.month),
    metricsLevel: 1,
    weekStart: WeekStart.monday,
  );

  final SplitMethod split;

  /// Also one file per project (first account level), on top of [split].
  final bool splitByProject;
  final String fileNameTemplate;

  /// Account depth used to group the Metrics totals, at least 1.
  final int metricsLevel;
  final WeekStart weekStart;

  FileSettings get fileSettings =>
      FileSettings(split, fileNameTemplate, splitByProject: splitByProject);

  AppSettings copyWith({
    SplitMethod? split,
    bool? splitByProject,
    String? fileNameTemplate,
    int? metricsLevel,
    WeekStart? weekStart,
  }) => AppSettings(
    split: split ?? this.split,
    splitByProject: splitByProject ?? this.splitByProject,
    fileNameTemplate: fileNameTemplate ?? this.fileNameTemplate,
    metricsLevel: metricsLevel ?? this.metricsLevel,
    weekStart: weekStart ?? this.weekStart,
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
    final byProject = prefs.getBool(_byProjectKey) ?? defaults.splitByProject;
    var template = prefs.getString(_templateKey);
    if (template == null ||
        validateFileNameTemplate(template, split, byProject: byProject) !=
            null) {
      template = defaultFileNameTemplate(split, byProject: byProject);
    }
    final level = prefs.getInt(_levelKey);
    return AppSettings(
      split: split,
      splitByProject: byProject,
      fileNameTemplate: template,
      metricsLevel: level != null && level >= 1 ? level : defaults.metricsLevel,
      weekStart:
          WeekStart.values.asNameMap()[prefs.getString(_weekStartKey)] ??
          defaults.weekStart,
    );
  }

  /// Changes how entries are spread over files. Files already written are not
  /// touched.
  ///
  /// A template that still is the default for the old choice follows the new
  /// one. A custom one is kept when it works for the new choice, otherwise it
  /// goes back to the default.
  Future<void> setSplit(SplitMethod split) =>
      _setSplitting(split, state.splitByProject);

  /// Also splits files by project (first level of the account). Same rule for
  /// the template as [setSplit].
  Future<void> setSplitByProject(bool byProject) =>
      _setSplitting(state.split, byProject);

  Future<void> _setSplitting(SplitMethod split, bool byProject) async {
    final old = state;
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
    await prefs.setBool(_byProjectKey, byProject);
    await prefs.setString(_templateKey, template);
    state = old.copyWith(
      split: split,
      splitByProject: byProject,
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
}
