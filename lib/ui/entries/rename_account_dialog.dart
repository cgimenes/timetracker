import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account.dart';
import '../../settings/app_settings.dart';
import '../../state/budgets.dart';
import '../../state/entries.dart';
import '../account_field.dart';

/// Asks which account to rename and its new name. Pops with `(from, to)`, or
/// null. Renames the account and its sub-accounts.
class RenameAccountDialog extends ConsumerStatefulWidget {
  const RenameAccountDialog({this.initialFrom = '', super.key});

  final String initialFrom;

  @override
  ConsumerState<RenameAccountDialog> createState() =>
      _RenameAccountDialogState();
}

class _RenameAccountDialogState extends ConsumerState<RenameAccountDialog> {
  late final _from = TextEditingController(text: widget.initialFrom);
  final _fromFocus = FocusNode();
  final _to = TextEditingController();

  @override
  void dispose() {
    _from.dispose();
    _fromFocus.dispose();
    _to.dispose();
    super.dispose();
  }

  String get _fromText => _from.text.trim();
  String get _toText => _to.text.trim();

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final s in ref.watch(entriesProvider).value?.entries ?? const [])
        if (renamedAccount(s.entry.account, _fromText, _toText) != null) s,
    ];
    final settings = ref.watch(settingsProvider);
    final goals =
        (ref.watch(budgetsProvider).value?.budgets ?? const [])
            .where((b) => renamedAccount(b.account, _fromText, _toText) != null)
            .length +
        settings.dailyGoals.keys
            .where((a) => renamedAccount(a, _fromText, _toText) != null)
            .length;
    final files = settings.fileSettings;
    final moves = entries.any((s) {
      final e = s.entry;
      final account = renamedAccount(e.account, _fromText, _toText)!;
      final target = files.nameFor(e.start, account);
      return target != files.nameFor(e.start, e.account) &&
          target != s.fileName;
    });

    final typed = _fromText.isNotEmpty && _toText.isNotEmpty;
    final invalid = typed ? validateRename(_fromText, _toText) : null;
    final none = typed && invalid == null && entries.isEmpty;
    final canRename = typed && invalid == null && entries.isNotEmpty;
    final examples = {
      for (final s in entries)
        '${s.entry.account} -> ${renamedAccount(s.entry.account, _fromText, _toText)}',
    }.take(3);

    return AlertDialog(
      title: const Text('Rename account'),
      // A set width: the field measures its own, which a dialog cannot ask.
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountField(
                controller: _from,
                focusNode: _fromFocus,
                label: 'From',
                fieldKey: const Key('rename-from'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('rename-to'),
                controller: _to,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'To',
                  hintText: 'clients:acme',
                  border: const OutlineInputBorder(),
                  errorText: invalid ?? (none ? 'No entries match' : null),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (canRename) ...[
                const SizedBox(height: 12),
                Text(
                  key: const Key('rename-preview'),
                  '${entries.length} '
                  '${entries.length == 1 ? 'entry' : 'entries'}'
                  '${goals == 0 ? '' : ', $goals ${goals == 1 ? 'goal' : 'goals'}'}'
                  ', sub-accounts included.',
                ),
                for (final example in examples) Text(example),
                if (moves)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Entries move to the files of the new project.',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('rename-save'),
          onPressed: canRename
              ? () => Navigator.pop(context, (_fromText, _toText))
              : null,
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
