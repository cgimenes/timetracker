import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validation.dart';
import '../../state/clock.dart';
import '../../state/derived.dart';
import '../account_field.dart';
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

  String? _error() =>
      validateEntry(account: _account.text.trim(), start: _now, now: _now);

  Future<void> _startNow() => _submit(null);

  Future<void> _startAt() => _submit(null, ask: true);

  /// Starts at [start], or asks for a time first when [ask] is true, or uses
  /// the current time when [start] is null.
  Future<void> _submit(DateTime? start, {bool ask = false}) async {
    if (_error() != null) return;
    // Close the keyboard (and the suggestions) right away.
    FocusManager.instance.primaryFocus?.unfocus();
    final account = _account.text.trim();
    if (ask) {
      start = await askStartTime(context, ref, account: account);
      if (start == null) return;
    }
    if (!mounted) return;
    await startEntry(context, ref, account, start ?? _now);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error();
    final accountText = _account.text.trim();
    final showError = error != null && accountText.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountField(
              controller: _account,
              focusNode: _accountFocus,
              errorText: showError ? error : null,
              onChanged: (_) => setState(() => _touched = true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('start'),
                    onPressed: error == null ? _startNow : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('start-at'),
                    onPressed: error == null ? _startAt : null,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Start at...'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
