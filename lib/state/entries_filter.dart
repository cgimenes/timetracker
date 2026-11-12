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

/// True when every word of [query] is in the account or the comment, ignoring
/// case. An empty query matches everything.
bool matchesSearch(Entry entry, String query) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final text = '${entry.account} ${entry.comment ?? ''}'.toLowerCase();
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
