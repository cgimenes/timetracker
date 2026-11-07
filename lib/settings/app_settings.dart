import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/file_naming.dart';
import '../core/metrics.dart';
import '../data/providers.dart';
import '../data/timeclock_repository.dart';

const _splitKey = 'split';
const _templateKey = 'fileNameTemplate';
const _levelKey = 'metricsLevel';
const _weekStartKey = 'weekStart';

class AppSettings {
  const AppSettings({
    required this.split,
    required this.fileNameTemplate,
    required this.metricsLevel,
    required this.weekStart,
  });

  factory AppSettings.defaults() => AppSettings(
    split: SplitMethod.month,
    fileNameTemplate: defaultFileNameTemplate(SplitMethod.month),
    metricsLevel: 1,
    weekStart: WeekStart.monday,
  );

  final SplitMethod split;
  final String fileNameTemplate;

  /// Account depth used to group the Home metrics, at least 1.
  final int metricsLevel;
  final WeekStart weekStart;

  FileSettings get fileSettings => FileSettings(split, fileNameTemplate);

  AppSettings copyWith({
    SplitMethod? split,
    String? fileNameTemplate,
    int? metricsLevel,
    WeekStart? weekStart,
  }) => AppSettings(
    split: split ?? this.split,
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
    var template = prefs.getString(_templateKey);
    if (template == null || validateFileNameTemplate(template, split) != null) {
      template = defaultFileNameTemplate(split);
    }
    final level = prefs.getInt(_levelKey);
    return AppSettings(
      split: split,
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
  /// A template that still is the default of the old split follows the new
  /// split. A custom one is kept when it works for the new split, otherwise it
  /// goes back to the default.
  Future<void> setSplit(SplitMethod split) async {
    final old = state;
    final followsDefault =
        old.fileNameTemplate == defaultFileNameTemplate(old.split);
    final keepsWorking =
        validateFileNameTemplate(old.fileNameTemplate, split) == null;
    final template = (!followsDefault && keepsWorking)
        ? old.fileNameTemplate
        : defaultFileNameTemplate(split);

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_splitKey, split.name);
    await prefs.setString(_templateKey, template);
    state = old.copyWith(split: split, fileNameTemplate: template);
  }

  /// Returns an error message, or null when the template was saved.
  Future<String?> setFileNameTemplate(String template) async {
    final error = validateFileNameTemplate(template, state.split);
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
