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

  @override
  void initState() {
    super.initState();
    // Follow the last closed entry, unless the user is editing the field.
    ref.listenManual(lastAccountProvider, (_, last) {
      if (last != null && !_accountFocus.hasFocus && _account.text != last) {
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AccountField(
                    controller: _account,
                    focusNode: _accountFocus,
                    errorText: showError ? error : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Level with the 56 dp field, whatever the error line does.
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filled(
                    key: const Key('start'),
                    tooltip: 'Start now',
                    iconSize: 28,
                    onPressed: error == null ? _startNow : null,
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('start-at'),
                onPressed: error == null ? _startAt : null,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Start at...'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
