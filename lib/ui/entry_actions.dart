import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/validation.dart';
import '../data/timeclock_repository.dart';
import '../state/clock.dart';
import '../state/entries.dart';
import 'account_field.dart';
import 'entries/edit_entry_page.dart';
import 'format.dart';
import 'ui_actions.dart';

/// Opens the Edit entry page for [stored].
void editEntry(BuildContext context, StoredEntry stored) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => EditEntryPage(stored)));
}

/// Starts the same account of [stored] again. See [startAgain].
Future<bool> restartEntry(
  BuildContext context,
  WidgetRef ref,
  StoredEntry stored,
) => startAgain(context, ref, stored.entry.account);

/// Asks for the account (prefilled with [account], editable) and whether to
/// start it now or at a time the user picks. Returns true when an entry was
/// started.
Future<bool> startAgain(
  BuildContext context,
  WidgetRef ref,
  String account,
) async {
  final choice = await showDialog<(String, bool)>(
    context: context,
    builder: (context) => _StartDialog(account),
  );
  if (choice == null || !context.mounted) return false;
  final (picked, now) = choice;
  final start = now
      ? ref.read(clockProvider)()
      : await askStartTime(context, ref, account: picked);
  if (start == null || !context.mounted) return false;
  final started = await startEntry(context, ref, picked, start);
  if (started && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Started $picked')));
  }
  return started;
}

/// Dialog with the account to start and the Now / Pick time buttons. Pops the
/// account and whether to start now.
class _StartDialog extends ConsumerStatefulWidget {
  const _StartDialog(this.account);

  final String account;

  @override
  ConsumerState<_StartDialog> createState() => _StartDialogState();
}

class _StartDialogState extends ConsumerState<_StartDialog> {
  late final _account = TextEditingController(text: widget.account);
  final _focus = FocusNode();

  @override
  void dispose() {
    _account.dispose();
    _focus.dispose();
    super.dispose();
  }

  String? _error() {
    final now = ref.read(clockProvider)();
    return validateEntry(account: _account.text.trim(), start: now, now: now);
  }

  void _done(bool now) => Navigator.pop(context, (_account.text.trim(), now));

  @override
  Widget build(BuildContext context) {
    final error = _error();
    final text = _account.text.trim();
    return AlertDialog(
      title: const Text('Start again?'),
      // A set width: the field measures its own, which a dialog cannot ask.
      content: SizedBox(
        width: double.maxFinite,
        child: AccountField(
          controller: _account,
          focusNode: _focus,
          errorText: error != null && text.isNotEmpty ? error : null,
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('restart-at'),
          onPressed: error == null ? () => _done(false) : null,
          child: const Text('Pick time'),
        ),
        FilledButton(
          key: const Key('restart-now'),
          onPressed: error == null ? () => _done(true) : null,
          child: const Text('Now'),
        ),
      ],
    );
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
