import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Shown by the tabs that need the files before a folder is chosen.
class ChooseFolderPrompt extends ConsumerWidget {
  const ChooseFolderPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Choose the folder where your timeclock files live.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('choose-folder'),
              onPressed: () => ref.read(treeUriProvider.notifier).pick(),
              child: const Text('Choose folder'),
            ),
          ],
        ),
      ),
    );
  }
}
