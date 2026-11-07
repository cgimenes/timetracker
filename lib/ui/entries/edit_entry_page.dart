import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account.dart';
import '../../core/validation.dart';
import '../../data/timeclock_repository.dart';
import '../../state/clock.dart';
import '../../state/entries.dart';
import '../account_field.dart';
import '../format.dart';
import '../ui_actions.dart';

/// Changes the account, start and end of one entry. Its comment, if any, is
/// kept as it is.
class EditEntryPage extends ConsumerStatefulWidget {
  const EditEntryPage(this.stored, {super.key});

  final StoredEntry stored;

  @override
  ConsumerState<EditEntryPage> createState() => _EditEntryPageState();
}

class _EditEntryPageState extends ConsumerState<EditEntryPage> {
  late final _account = TextEditingController(
    text: widget.stored.entry.account,
  );
  final _focus = FocusNode();
  late DateTime _start = widget.stored.entry.start;
  late DateTime? _end = widget.stored.entry.end;

  @override
  void dispose() {
    _account.dispose();
    _focus.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(clockProvider)();

  String? _error() => validateEntry(
    account: _account.text.trim(),
    start: _start,
    end: _end,
    comment: widget.stored.entry.comment,
    now: _now,
  );

  Future<void> _pick({required bool start}) async {
    final now = _now;
    final current = start ? _start : (_end ?? now);
    final picked = await pickDateTime(
      context,
      initial: current,
      first: DateTime(now.year - 2),
      last: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  void _setRunning(bool running) {
    setState(() {
      if (running) {
        _end = null;
      } else {
        // A sensible first end: now, or a minute after the start if the
        // entry starts in the future of the clock.
        final now = _now;
        _end = now.isAfter(_start)
            ? now
            : _start.add(const Duration(minutes: 1));
      }
    });
  }

  Future<void> _save() async {
    if (_error() != null) return;
    await guard(
      context,
      () => ref
          .read(entriesProvider.notifier)
          .replace(
            widget.stored,
            account: _account.text.trim(),
            start: _start,
            end: _end,
            comment: widget.stored.entry.comment,
          ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error();
    final accountError = validateAccount(_account.text.trim());
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit entry'),
        actions: [
          TextButton(
            key: const Key('save'),
            onPressed: error == null ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AccountField(
            controller: _account,
            focusNode: _focus,
            errorText: accountError,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('edit-start'),
            title: const Text('Start'),
            subtitle: Text(formatDateTime(_start)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () => _pick(start: true),
          ),
          SwitchListTile(
            key: const Key('edit-running'),
            title: const Text('Still running'),
            value: _end == null,
            onChanged: _setRunning,
          ),
          if (_end != null)
            ListTile(
              key: const Key('edit-end'),
              title: const Text('End'),
              subtitle: Text(formatDateTime(_end!)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () => _pick(start: false),
            ),
          if (error != null && accountError == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: TextStyle(color: scheme.error)),
            ),
        ],
      ),
    );
  }
}
