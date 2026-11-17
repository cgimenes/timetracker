import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/account.dart';
import '../core/timeclock.dart';
import '../data/timeclock_repository.dart';
import 'entries.dart';

/// Text typed in the Entries search field.
final entriesSearchProvider = NotifierProvider<EntriesSearchNotifier, String>(
  EntriesSearchNotifier.new,
);

class EntriesSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// Project (first account level) picked in the Entries chips, or null for all.
final entriesProjectProvider =
    NotifierProvider<EntriesProjectNotifier, String?>(
      EntriesProjectNotifier.new,
    );

class EntriesProjectNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Picks [project]; picking the one already picked shows all again.
  void toggle(String project) => state = state == project ? null : project;

  void clear() => state = null;
}

const _weekdayNames = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// True when every word of [query] is in the account, the comment or the day
/// the entry starts on, ignoring case. An empty query matches everything.
///
/// The day is its date (`2026-10-29`, so `10-29` or `2026-10` work too) and
/// its weekday name (`thursday`, so `thu` works).
bool matchesSearch(Entry entry, String query) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final s = entry.start;
  final date =
      '${s.year.toString().padLeft(4, '0')}-'
      '${s.month.toString().padLeft(2, '0')}-'
      '${s.day.toString().padLeft(2, '0')}';
  final text =
      '${entry.account} ${entry.comment ?? ''} $date '
              '${_weekdayNames[s.weekday - 1]}'
          .toLowerCase();
  return words.every(text.contains);
}

List<StoredEntry> _all(Ref ref) =>
    ref.watch(entriesProvider).value?.entries ?? const [];

/// Projects of the finished entries, sorted, for the chips.
final entryProjectsProvider = Provider<List<String>>((ref) {
  final projects = {
    for (final e in _all(ref))
      if (!e.entry.isRunning) projectOf(e.entry.account),
  };
  return projects.toList()..sort();
});

/// Finished entries that match the search and the picked project, newest
/// first. Running entries are on the Track tab.
final filteredEntriesProvider = Provider<List<StoredEntry>>((ref) {
  final query = ref.watch(entriesSearchProvider);
  final picked = ref.watch(entriesProjectProvider);
  // A project with no entries left (all removed) filters nothing.
  final project = ref.watch(entryProjectsProvider).contains(picked)
      ? picked
      : null;
  return _all(ref)
      .where(
        (e) =>
            !e.entry.isRunning &&
            (project == null || projectOf(e.entry.account) == project) &&
            matchesSearch(e.entry, query),
      )
      .toList();
});
