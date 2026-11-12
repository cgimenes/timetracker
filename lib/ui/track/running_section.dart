import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validation.dart';
import '../../data/timeclock_repository.dart';
import '../../state/clock.dart';
import '../../state/derived.dart';
import '../../state/entries.dart';
import '../entries/edit_entry_page.dart';
import '../entry_actions.dart';
import '../format.dart';
import '../ui_actions.dart';

/// Entries that are running, with a live timer and Stop.
class RunningSection extends ConsumerWidget {
  const RunningSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(runningProvider);
    final now = ref.watch(nowProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Running',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (running.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text('Nothing running'),
              ),
            for (final stored in running)
              ListTile(
                key: ValueKey('${stored.fileName}:${stored.entry.inIndex}'),
                title: Text(stored.entry.account),
                subtitle: Text(
                  'since ${formatDateTime(stored.entry.start)}'
                  '${stored.entry.comment == null ? '' : '\n${stored.entry.comment}'}',
                ),
                isThreeLine: stored.entry.comment != null,
                leading: Text(
                  formatHms(stored.entry.duration(now)),
                  key: const Key('elapsed'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.tonal(
                      key: const Key('stop'),
                      onPressed: () => guard(context, () {
                        // End must come after start, and the clock has
                        // second resolution.
                        final clock = ref.read(clockProvider)();
                        final end = clock.isAfter(stored.entry.start)
                            ? clock
                            : stored.entry.start.add(
                                const Duration(seconds: 1),
                              );
                        return ref
                            .read(entriesProvider.notifier)
                            .stop(stored, end);
                      }),
                      child: const Text('Stop'),
                    ),
                    PopupMenuButton<String>(
                      key: const Key('stop-menu'),
                      onSelected: (action) => switch (action) {
                        'at' => _stopAt(context, ref, stored),
                        'edit' => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EditEntryPage(stored),
                          ),
                        ),
                        _ => cancelRunningEntry(context, ref, stored),
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'at', child: Text('Stop at...')),
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel entry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopAt(
    BuildContext context,
    WidgetRef ref,
    StoredEntry stored,
  ) async {
    final now = ref.read(clockProvider)();
    final picked = await pickDateTime(
      context,
      initial: now,
      first: DateTime(
        stored.entry.start.year,
        stored.entry.start.month,
        stored.entry.start.day,
      ),
      last: DateTime(now.year, now.month, now.day),
    );
    if (picked == null || !context.mounted) return;
    final error = validateEntry(
      account: stored.entry.account,
      start: stored.entry.start,
      end: picked,
      now: now,
    );
    if (error != null) {
      return guard(context, () async => throw ArgumentError(error));
    }
    await guard(
      context,
      () => ref.read(entriesProvider.notifier).stop(stored, picked),
    );
  }
}
