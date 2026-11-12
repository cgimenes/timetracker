import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/validation.dart';
import '../data/timeclock_repository.dart';
import '../state/clock.dart';
import '../state/derived.dart';
import '../state/entries.dart';

/// Runs [action] and shows the failure, if any, in a snack bar.
Future<void> guard(BuildContext context, Future<void> Function() action) async {
  String? message;
  try {
    await action();
  } on StaleEntryException catch (e) {
    message =
        '${e.fileName} changed on disk. Entries were reloaded, try again.';
  } on ArgumentError catch (e) {
    message = '${e.message}';
  } catch (e) {
    message = '$e';
  }
  if (message != null && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Asks whether to start [account] although it already runs. hledger cannot
/// read a file with overlapping sessions of the same account.
Future<bool> confirmDuplicateRunning(
  BuildContext context,
  String account,
) async {
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

/// Asks for a start time and returns it, or null when cancelled or invalid
/// (the problem is shown in a snack bar).
Future<DateTime?> askStartTime(
  BuildContext context,
  WidgetRef ref, {
  required String account,
}) async {
  final now = ref.read(clockProvider)();
  final picked = await pickDateTime(
    context,
    initial: now,
    first: DateTime(now.year - 2),
    last: DateTime(now.year, now.month, now.day),
  );
  if (picked == null || !context.mounted) return null;
  final error = validateEntry(account: account, start: picked, now: now);
  if (error != null) {
    await guard(context, () async => throw ArgumentError(error));
    return null;
  }
  return picked;
}

/// Starts [account] at [start]. Warns first when it already runs. Returns
/// true when the entry was started.
Future<bool> startEntry(
  BuildContext context,
  WidgetRef ref,
  String account,
  DateTime start,
) async {
  final running = ref.read(runningProvider);
  if (running.any((e) => e.entry.account == account) &&
      !await confirmDuplicateRunning(context, account)) {
    return false;
  }
  if (!context.mounted) return false;
  var started = false;
  await guard(context, () async {
    await ref.read(entriesProvider.notifier).start(account, start);
    started = true;
  });
  return started;
}

/// Asks for a date and a time in one dialog. Null when the user cancels.
///
/// [last] bounds the date (its day is selectable); time precision is minutes.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _DateTimeDialog(initial: initial, first: first, last: last),
);

class _DateTimeDialog extends StatefulWidget {
  const _DateTimeDialog({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_DateTimeDialog> createState() => _DateTimeDialogState();
}

class _DateTimeDialogState extends State<_DateTimeDialog> {
  late DateTime _date = widget.initial.isAfter(widget.last)
      ? widget.last
      : widget.initial;
  late final _hour = TextEditingController(
    text: widget.initial.hour.toString().padLeft(2, '0'),
  );
  late final _minute = TextEditingController(
    text: widget.initial.minute.toString().padLeft(2, '0'),
  );

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c, int max) {
    final n = int.tryParse(c.text);
    return n != null && n >= 0 && n <= max ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final hour = _parse(_hour, 23);
    final minute = _parse(_minute, 59);
    final valid = hour != null && minute != null;

    return AlertDialog(
      contentPadding: const EdgeInsets.only(top: 16),
      // The width of Material's own date picker dialog, which is what the
      // calendar is laid out for.
      content: SizedBox(
        width: 328,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CalendarDatePicker(
                initialDate: _date,
                firstDate: widget.first,
                lastDate: widget.last,
                onDateChanged: (d) => setState(() => _date = d),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _TimeField(
                      key: const Key('dt-hour'),
                      controller: _hour,
                      label: 'Hour',
                      valid: hour != null,
                      onChanged: () => setState(() {}),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        ':',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    _TimeField(
                      key: const Key('dt-minute'),
                      controller: _minute,
                      label: 'Minute',
                      valid: minute != null,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
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
          key: const Key('dt-ok'),
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  DateTime(_date.year, _date.month, _date.day, hour, minute),
                )
              : null,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    super.key,
    required this.controller,
    required this.label,
    required this.valid,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool valid;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    // A red border instead of error text, so the field keeps its height and
    // nothing in the dialog moves.
    OutlineInputBorder border(Color? color) => OutlineInputBorder(
      borderSide: color == null ? const BorderSide() : BorderSide(color: color),
    );

    return SizedBox(
      width: 88,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: InputDecoration(
          labelText: label,
          floatingLabelAlignment: FloatingLabelAlignment.center,
          border: const OutlineInputBorder(),
          enabledBorder: valid ? null : border(error),
          focusedBorder: valid ? null : border(error),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
