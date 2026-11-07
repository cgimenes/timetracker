import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../state/entries.dart';
import '../choose_folder.dart';
import 'add_entry_card.dart';
import 'running_section.dart';

/// Start an entry and see what is running.
class TrackPage extends ConsumerWidget {
  const TrackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFolder = ref.watch(treeUriProvider) != null;
    final entries = hasFolder ? ref.watch(entriesProvider) : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: !hasFolder
            ? const ChooseFolderPrompt()
            : RefreshIndicator(
                // Pull to read the files again, for example after a sync.
                onRefresh: () => ref.read(entriesProvider.notifier).reload(),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (entries!.hasError && !entries.hasValue)
                      _LoadError('${entries.error}')
                    else ...[
                      const AddEntryCard(),
                      const RunningSection(),
                    ],
                  ].expand((w) => [w, const SizedBox(height: 12)]).toList(),
                ),
              ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('Could not read the files: $message'),
    ),
  );
}
