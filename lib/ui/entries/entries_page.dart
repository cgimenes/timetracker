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
import '../ui_actions.dart';
import 'edit_entry_page.dart';

/// Every entry, newest first, grouped by day.
class EntriesPage extends ConsumerWidget {
  const EntriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFolder = ref.watch(treeUriProvider) != null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: !hasFolder
            ? const ChooseFolderPrompt()
            : const Column(
                children: [
                  _FilterBar(),
                  Expanded(child: _EntryList()),
                ],
              ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(entriesFilterProvider);
    final notifier = ref.read(entriesFilterProvider.notifier);
    final maxDepth = ref.watch(maxAccountDepthProvider);
    final options = ref.watch(filterPrefixOptionsProvider);
    // Keep the selected level reachable even if the data got shallower.
    final depth = maxDepth < filter.level ? filter.level : maxDepth;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          DropdownButton<int>(
            key: const Key('filter-level'),
            value: filter.level,
            items: [
              for (var l = 1; l <= depth; l++)
                DropdownMenuItem(value: l, child: Text('Level $l')),
            ],
            onChanged: (l) => l == null ? null : notifier.setLevel(l),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String?>(
              key: const Key('filter-prefix'),
              isExpanded: true,
              value: filter.prefix,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: notifier.setPrefix,
            ),
          ),
        ],
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
    final range = entry.isRunning
        ? 'since ${formatTimeOfDay(entry.start)}, running'
        : '${formatTimeOfDay(entry.start)} to ${formatTimeOfDay(entry.end!)}'
              '${entry.end!.day == entry.start.day ? '' : ' (${formatDate(entry.end!)})'}';

    return ListTile(
      title: Text(entry.account),
      subtitle: Text(
        entry.comment == null ? range : '$range\n${entry.comment}',
      ),
      isThreeLine: entry.comment != null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.isRunning
                ? formatHms(entry.duration(now))
                : formatHm(entry.duration(now)),
          ),
          PopupMenuButton<String>(
            key: ValueKey('menu-${stored.fileName}:${entry.inIndex}'),
            onSelected: (action) => switch (action) {
              'restart' => _restart(context, ref),
              'edit' => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => EditEntryPage(stored)),
              ),
              _ => _confirmRemove(context, ref),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'restart', child: Text('Start again')),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }

  /// Starts the same account again, now or at a time the user picks.
  Future<void> _restart(BuildContext context, WidgetRef ref) async {
    final account = stored.entry.account;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start again?'),
        content: Text(account),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('restart-at'),
            onPressed: () => Navigator.pop(context, 'at'),
            child: const Text('Pick time'),
          ),
          FilledButton(
            key: const Key('restart-now'),
            onPressed: () => Navigator.pop(context, 'now'),
            child: const Text('Now'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final start = choice == 'now'
        ? ref.read(clockProvider)()
        : await askStartTime(context, ref, account: account);
    if (start == null || !context.mounted) return;
    final started = await startEntry(context, ref, account, start);
    if (started && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Started $account')));
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final entry = stored.entry;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove entry?'),
        content: Text(
          '${entry.account}\n'
          '${entry.isRunning ? 'since ${formatDateTime(entry.start)}' : formatRange(entry.start, entry.end!)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await guard(
      context,
      () => ref.read(entriesProvider.notifier).remove(stored),
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
