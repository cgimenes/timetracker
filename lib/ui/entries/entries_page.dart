import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/timeclock_repository.dart';
import '../../state/clock.dart';
import '../../state/derived.dart';
import '../../state/entries.dart';
import '../../state/entries_filter.dart';
import '../choose_folder.dart';
import '../load_error.dart';
import '../format.dart';
import '../../state/navigation.dart';
import '../entry_actions.dart';
import 'edit_entry_page.dart';

/// Id of the entry whose actions are shown in its row, if any. One at a time.
final _openEntryProvider = NotifierProvider<_OpenEntry, String?>(
  _OpenEntry.new,
);

class _OpenEntry extends Notifier<String?> {
  @override
  String? build() => null;

  void toggle(String id) => state = state == id ? null : id;

  void close() => state = null;
}

String _idOf(StoredEntry s) =>
    '${s.fileName}:${s.entry.inIndex}:${s.entry.start.millisecondsSinceEpoch}';

/// Finished entries, newest first, grouped by day.
class EntriesPage extends ConsumerWidget {
  const EntriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFolder = ref.watch(treeUriProvider) != null;

    return Scaffold(
      body: SafeArea(
        child: !hasFolder
            ? const ChooseFolderPrompt()
            : const Column(
                children: [
                  _SearchBar(),
                  Expanded(child: _EntryList()),
                ],
              ),
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(String query) {
    ref.read(entriesSearchProvider.notifier).set(query);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        key: const Key('search'),
        controller: _controller,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search account or comment',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('search-clear'),
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    _set('');
                  },
                ),
        ),
        onChanged: _set,
      ),
    );
  }
}

sealed class _Row {
  const _Row();
}

class _Warnings extends _Row {
  const _Warnings(this.warnings);
  final List<FileWarning> warnings;
}

class _DayHeader extends _Row {
  const _DayHeader(this.day, this.total);
  final DateTime day;
  final Duration total;
}

class _EntryRow extends _Row {
  const _EntryRow(this.stored);
  final StoredEntry stored;
}

class _EntryList extends ConsumerWidget {
  const _EntryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider);
    final filtered = ref.watch(filteredEntriesProvider);
    final warnings = ref.watch(warningsProvider);
    final now = ref.watch(nowProvider);
    // The open row belongs to the old list when the search changes.
    ref.listen(entriesSearchProvider, (_, _) {
      ref.read(_openEntryProvider.notifier).close();
    });

    if (entries.hasError && !entries.hasValue) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [LoadErrorCard(entries.error)],
      );
    }

    final rows = <_Row>[
      if (warnings.isNotEmpty) _Warnings(warnings),
      ..._group(filtered, now),
    ];

    return RefreshIndicator(
      onRefresh: () => ref.read(entriesProvider.notifier).reload(),
      child: rows.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No entries')),
                ),
              ],
            )
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => switch (rows[i]) {
                _Warnings(:final warnings) => _WarningsBanner(warnings),
                _DayHeader(:final day, :final total) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatDate(day),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        formatHm(total),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                _EntryRow(:final stored) => _EntryTile(stored),
              },
            ),
    );
  }

  /// Day headers (with the day's total) followed by the day's entries.
  /// [entries] is already newest first.
  List<_Row> _group(List<StoredEntry> entries, DateTime now) {
    final rows = <_Row>[];
    var i = 0;
    while (i < entries.length) {
      final start = entries[i].entry.start;
      final day = DateTime(start.year, start.month, start.day);
      final group = <StoredEntry>[];
      while (i < entries.length && _sameDay(entries[i].entry.start, day)) {
        group.add(entries[i++]);
      }
      final total = group.fold(
        Duration.zero,
        (sum, e) => sum + e.entry.duration(now),
      );
      rows
        ..add(_DayHeader(day, total))
        ..addAll(group.map(_EntryRow.new));
    }
    return rows;
  }

  bool _sameDay(DateTime t, DateTime day) =>
      t.year == day.year && t.month == day.month && t.day == day.day;
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile(this.stored);

  final StoredEntry stored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = stored.entry;
    final now = ref.watch(nowProvider);
    final range =
        '${formatTimeOfDay(entry.start)} to ${formatTimeOfDay(entry.end!)}'
        '${entry.end!.day == entry.start.day ? '' : ' (${formatDate(entry.end!)})'}';

    final id = _idOf(stored);
    final open = ref.watch(_openEntryProvider.select((o) => o == id));
    final notifier = ref.read(_openEntryProvider.notifier);

    return ListTile(
      key: ValueKey('entry-$id'),
      selected: open,
      title: Text(entry.account),
      subtitle: Text(
        entry.comment == null ? range : '$range\n${entry.comment}',
      ),
      isThreeLine: entry.comment != null,
      onTap: () => notifier.toggle(id),
      trailing: open
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Start again',
                  icon: const Icon(Icons.replay),
                  onPressed: () async {
                    notifier.close();
                    // Read before the await: the row may be gone afterwards.
                    final tab = ref.read(homeTabProvider.notifier);
                    final started = await restartEntry(context, ref, stored);
                    // Show what is running now.
                    if (started) tab.select(HomeTab.track);
                  },
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    notifier.close();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EditEntryPage(stored),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    notifier.close();
                    confirmRemoveEntry(context, ref, stored);
                  },
                ),
              ],
            )
          : Text(formatHm(entry.duration(now))),
    );
  }
}

class _WarningsBanner extends StatelessWidget {
  const _WarningsBanner(this.warnings);

  final List<FileWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('warnings'),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: scheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.warning_amber),
        title: Text(
          warnings.length == 1
              ? '1 problem in the files'
              : '${warnings.length} problems in the files',
        ),
        subtitle: const Text('Tap for details'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Problems in the files'),
            content: SingleChildScrollView(
              child: Text(warnings.map((w) => '$w').join('\n')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
