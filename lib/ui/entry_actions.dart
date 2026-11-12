import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/timeclock_repository.dart';
import '../state/clock.dart';
import '../state/entries.dart';
import 'entries/edit_entry_page.dart';
import 'format.dart';
import 'ui_actions.dart';

/// Opens the Edit entry page for [stored].
void editEntry(BuildContext context, StoredEntry stored) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => EditEntryPage(stored)));
}

/// Starts the same account again, now or at a time the user picks.
Future<void> restartEntry(
  BuildContext context,
  WidgetRef ref,
  StoredEntry stored,
) async {
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

Future<void> confirmRemoveEntry(
  BuildContext context,
  WidgetRef ref,
  StoredEntry stored,
) async {
  final entry = stored.entry;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove entry?'),
      content: Text(
        '${entry.account}\n${formatRange(entry.start, entry.end!)}',
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
  await guard(context, () => ref.read(entriesProvider.notifier).remove(stored));
}

/// Throws the running entry away, as if it never started.
Future<void> cancelRunningEntry(
  BuildContext context,
  WidgetRef ref,
  StoredEntry stored,
) async {
  final entry = stored.entry;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel entry?'),
      content: Text(
        '${entry.account}\nsince ${formatDateTime(entry.start)}\n\n'
        'The entry is removed and no time is recorded.',
      ),
      actions: [
        TextButton(
          key: const Key('keep-running'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep running'),
        ),
        FilledButton(
          key: const Key('cancel-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cancel entry'),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;
  await guard(context, () => ref.read(entriesProvider.notifier).remove(stored));
}
