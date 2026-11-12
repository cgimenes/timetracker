import 'package:flutter/material.dart';

import '../theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/clock.dart';
import '../../state/derived.dart';
import '../ui_actions.dart';

/// How many accounts are listed.
const quickStartCount = 3;

/// A "Quick start" section listing the most used accounts (the top
/// [quickStartCount] by frecency), each with a play button that starts it now.
class QuickStart extends ConsumerWidget {
  const QuickStart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref
        .watch(accountSuggestionsProvider)
        .take(quickStartCount)
        .toList();
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
                  tooltip: 'Start now',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => startEntry(
                    context,
                    ref,
                    account,
                    ref.read(clockProvider)(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
