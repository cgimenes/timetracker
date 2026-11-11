import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/timeclock_repository.dart';

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
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: 320,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TimeField(
                      key: const Key('dt-hour'),
                      controller: _hour,
                      label: 'Hour',
                      valid: hour != null,
                      onChanged: () => setState(() {}),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(':'),
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
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: valid ? null : '',
        errorStyle: const TextStyle(height: 0),
      ),
      onChanged: (_) => onChanged(),
    ),
  );
}
