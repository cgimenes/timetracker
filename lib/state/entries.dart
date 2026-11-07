import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/timeclock_repository.dart';
import '../settings/app_settings.dart';

/// Everything in the directory, plus the actions that change it.
///
/// The state keeps the previous data while reloading, so screens do not flash
/// empty. After every action the files are read again: the files are the only
/// source of truth.
final entriesProvider = AsyncNotifierProvider<EntriesNotifier, LoadResult>(
  EntriesNotifier.new,
);

class EntriesNotifier extends AsyncNotifier<LoadResult> {
  @override
  Future<LoadResult> build() => ref.watch(timeclockRepositoryProvider).load();

  TimeclockRepository get _repo => ref.read(timeclockRepositoryProvider);
  FileSettings get _files => ref.read(settingsProvider).fileSettings;

  /// Reads the files again, whatever changed.
  Future<void> reload() async {
    try {
      state = AsyncData(await _repo.load());
    } catch (e, st) {
      state = AsyncError<LoadResult>(e, st);
    }
  }

  /// Reloads only when a file was added, removed or modified since the last
  /// load. Call it when the app comes back to the foreground.
  Future<void> reloadIfChanged() async {
    final current = state.value;
    if (current == null || await _repo.hasChanged(current)) await reload();
  }

  Future<void> start(String account, DateTime start, {String? comment}) =>
      _change(
        (repo) =>
            repo.startEntry(account, start, comment: comment, settings: _files),
      );

  Future<void> stop(StoredEntry entry, DateTime time) =>
      _change((repo) => repo.stopEntry(entry, time));

  /// Clocks out the oldest running entry of [account]. False when none runs.
  Future<bool> stopAccount(String account, DateTime time) async {
    var stopped = false;
    await _change((repo) async {
      stopped = await repo.stopOldestRunning(account, time);
    });
    return stopped;
  }

  Future<void> replace(
    StoredEntry entry, {
    required String account,
    required DateTime start,
    DateTime? end,
    String? comment,
  }) => _change(
    (repo) => repo.replaceEntry(
      entry,
      account: account,
      start: start,
      end: end,
      comment: comment,
      settings: _files,
    ),
  );

  Future<void> remove(StoredEntry entry) =>
      _change((repo) => repo.removeEntry(entry));

  /// Runs [action], then reloads even when it failed, so a
  /// [StaleEntryException] leaves the screen showing the files as they are.
  Future<void> _change(
    Future<void> Function(TimeclockRepository repo) action,
  ) async {
    try {
      await action(_repo);
    } finally {
      await reload();
    }
  }
}
