import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account.dart';
import '../../core/validation.dart';
import '../../state/clock.dart';
import '../../state/derived.dart';
import '../../state/entries.dart';
import '../account_field.dart';
import '../format.dart';
import '../ui_actions.dart';

/// Form to start an entry.
class AddEntryCard extends ConsumerStatefulWidget {
  const AddEntryCard({super.key});

  @override
  ConsumerState<AddEntryCard> createState() => _AddEntryCardState();
}

class _AddEntryCardState extends ConsumerState<AddEntryCard> {
  final _account = TextEditingController();
  final _accountFocus = FocusNode();

  /// Null means "now".
  DateTime? _start;
  var _touched = false;

  @override
  void initState() {
    super.initState();
    // Prefill with the last used account, until the user types something.
    ref.listenManual(lastAccountProvider, (_, last) {
      if (!_touched && last != null && _account.text.isEmpty) {
        _account.text = last;
        if (mounted) setState(() {});
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _account.dispose();
    _accountFocus.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(clockProvider)();

  String? _error() => validateEntry(
    account: _account.text.trim(),
    start: _start ?? _now,
    now: _now,
  );

  Future<void> _pickStart() async {
    final now = _now;
    final picked = await pickDateTime(
      context,
      initial: _start ?? now,
      first: DateTime(now.year - 2),
      last: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<bool> _confirmDuplicate(String account) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Already running'),
        content: Text(
          '$account is already running. hledger cannot read a file with two '
          'overlapping sessions of the same account until one of them is '
          'stopped or edited.\n\nStart it anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start anyway'),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  Future<void> _submit() async {
    if (_error() != null) return;
    // Close the keyboard (and the suggestions) right away.
    FocusManager.instance.primaryFocus?.unfocus();
    final account = _account.text.trim();
    final running = ref.read(runningProvider);
    if (running.any((e) => e.entry.account == account) &&
        !await _confirmDuplicate(account)) {
      return;
    }
    if (!mounted) return;

    await guard(
      context,
      () => ref.read(entriesProvider.notifier).start(account, _start ?? _now),
    );
    if (!mounted) return;
    setState(() {
      _start = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error();
    final accountText = _account.text.trim();
    // Show the account problem once something is typed; time problems always.
    final showError =
        error != null && (accountText.isNotEmpty || _start != null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            AccountField(
              controller: _account,
              focusNode: _accountFocus,
              errorText: showError && validateAccount(accountText) != null
                  ? error
                  : null,
              onChanged: (_) => setState(() => _touched = true),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('start-time'),
                    onPressed: _pickStart,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _start == null ? 'Starts now' : formatDateTime(_start!),
                    ),
                  ),
                ),
                if (_start != null)
                  IconButton(
                    key: const Key('start-now'),
                    tooltip: 'Use the current time',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _start = null),
                  ),
              ],
            ),
            if (showError && validateAccount(accountText) == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('start'),
              onPressed: error == null ? _submit : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}
