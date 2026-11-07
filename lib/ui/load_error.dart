import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../state/entries.dart';

/// Shown when the files cannot be read, for example because the folder was
/// deleted or moved. Lets the user try again or pick another folder.
class LoadErrorCard extends ConsumerWidget {
  const LoadErrorCard(this.error, {super.key});

  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('load-error'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Could not read the files',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The folder may have been moved, deleted or its access removed.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const Key('retry'),
                  onPressed: () => ref.read(entriesProvider.notifier).reload(),
                  child: const Text('Try again'),
                ),
                OutlinedButton(
                  key: const Key('pick-another'),
                  onPressed: () => ref.read(treeUriProvider.notifier).pick(),
                  child: const Text('Choose another folder'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
