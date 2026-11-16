import 'package:flutter/material.dart';

import '../theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/derived.dart';
import '../entry_actions.dart';

/// A "Quick start" section listing the accounts of the last [quickStartCount]
/// entries that do not run now (each once, newest first), each with a play
/// button that asks the account and when to start it.
class QuickStart extends ConsumerWidget {
  const QuickStart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(recentAccountsProvider);
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('quick-start'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Quick start',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final account in accounts)
              ListTile(
                contentPadding: trailingFilledButtonTilePadding,
                title: Text(account),
                trailing: IconButton.filledTonal(
                  key: Key('quick-$account'),
                  tooltip: 'Start...',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => startAgain(context, ref, account),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
