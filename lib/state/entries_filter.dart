import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/account.dart';
import '../data/timeclock_repository.dart';
import 'entries.dart';

/// Entries tab filter: accounts whose first [level] segments equal [prefix].
/// A null [prefix] shows everything.
class EntriesFilter {
  const EntriesFilter({this.level = 1, this.prefix});

  final int level;
  final String? prefix;

  bool matches(String account) =>
      prefix == null || truncateAccount(account, level) == prefix;
}

final entriesFilterProvider =
    NotifierProvider<EntriesFilterNotifier, EntriesFilter>(
      EntriesFilterNotifier.new,
    );

class EntriesFilterNotifier extends Notifier<EntriesFilter> {
  @override
  EntriesFilter build() => const EntriesFilter();

  /// Changing the level clears the prefix: it belongs to the old level.
  void setLevel(int level) => state = EntriesFilter(level: level);

  void setPrefix(String? prefix) =>
      state = EntriesFilter(level: state.level, prefix: prefix);
}

List<StoredEntry> _all(Ref ref) =>
    ref.watch(entriesProvider).value?.entries ?? const [];

/// Deepest account in the files, at least 1: the largest useful filter level.
final maxAccountDepthProvider = Provider<int>((ref) {
  var depth = 1;
  for (final e in _all(ref)) {
    final d = accountDepth(e.entry.account);
    if (d > depth) depth = d;
  }
  return depth;
});

/// Values the prefix can take at the current level, sorted. Keeps the
/// selected one even when no entry has it any more.
final filterPrefixOptionsProvider = Provider<List<String>>((ref) {
  final filter = ref.watch(entriesFilterProvider);
  final options = {
    for (final e in _all(ref)) truncateAccount(e.entry.account, filter.level),
    ?filter.prefix,
  }.toList()..sort();
  return options;
});

/// Entries that pass the filter, newest first.
final filteredEntriesProvider = Provider<List<StoredEntry>>((ref) {
  final filter = ref.watch(entriesFilterProvider);
  return _all(ref).where((e) => filter.matches(e.entry.account)).toList();
});
