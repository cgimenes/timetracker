import 'package:flutter/material.dart';

import 'date_time_fields.dart';

/// Asks for a date and a time in one dialog. Null when the user cancels.
///
/// The date is picked with day chips (the last three days up to [last]) and
/// a calendar behind "Other date...". The time is picked on the Material
/// clock dial, opened from the time tile. Time precision is minutes.
///
/// [first] and [last] bound the date (both days are selectable). The dialog
/// refuses a moment after [notAfter] and one that is not after [after], and
/// says why, so the caller gets a valid answer.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  DateTime? notAfter,
  DateTime? after,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _DateTimeDialog(
    initial: initial,
    first: first,
    last: last,
    notAfter: notAfter,
    after: after,
  ),
);

class _DateTimeDialog extends StatefulWidget {
  const _DateTimeDialog({
    required this.initial,
    required this.first,
    required this.last,
    required this.notAfter,
    required this.after,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final DateTime? notAfter;
  final DateTime? after;

  @override
  State<_DateTimeDialog> createState() => _DateTimeDialogState();
}

class _DateTimeDialogState extends State<_DateTimeDialog> {
  late DateTime _moment = widget.initial;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Date and time'),
      content: SizedBox(
        width: 328,
        child: SingleChildScrollView(
          child: DateTimeFields(
            initial: widget.initial,
            first: widget.first,
            last: widget.last,
            notAfter: widget.notAfter,
            after: widget.after,
            onChanged: (moment, error) => setState(() {
              _moment = moment;
              _error = error;
            }),
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
          onPressed: _error == null
              ? () => Navigator.pop(context, _moment)
              : null,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
