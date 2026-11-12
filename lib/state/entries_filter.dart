import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Finished entries that match the search, newest first. Running entries are
/// on the Track tab.
final filteredEntriesProvider = Provider<List<StoredEntry>>((ref) {
  final query = ref.watch(entriesSearchProvider);
  return _all(ref)
      .where((e) => !e.entry.isRunning && matchesSearch(e.entry, query))
      .toList();
});
