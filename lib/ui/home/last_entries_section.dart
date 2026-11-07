import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/clock.dart';
import '../../state/derived.dart';
import '../format.dart';

/// The three most recent finished entries.
class LastEntriesSection extends ConsumerWidget {
  const LastEntriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(lastFinishedProvider);
    final now = ref.watch(clockProvider)();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Last entries',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text('No entries yet'),
              ),
            for (final stored in entries)
              ListTile(
                title: Text(stored.entry.account),
                subtitle: Text(
                  formatRange(stored.entry.start, stored.entry.end!),
                ),
                trailing: Text(
                  formatHm(stored.entry.duration(now)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
