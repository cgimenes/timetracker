import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/clock.dart';
import '../../state/derived.dart';
import '../ui_actions.dart';

/// How many accounts get a button.
const quickStartCount = 3;

/// One button per frequently used account (the top [quickStartCount] by
/// frecency) that starts it now.
class QuickStart extends ConsumerWidget {
  const QuickStart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref
        .watch(accountSuggestionsProvider)
        .take(quickStartCount)
        .toList();
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      key: const Key('quick-start'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final account in accounts)
          FilledButton.tonalIcon(
            key: Key('quick-$account'),
            icon: const Icon(Icons.play_arrow),
            label: Text(account),
            onPressed: () =>
                startEntry(context, ref, account, ref.read(clockProvider)()),
          ),
      ],
    );
  }
}
