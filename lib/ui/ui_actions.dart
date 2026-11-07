import 'package:flutter/material.dart';

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

/// Asks for a date, then a time. Null when the user cancels.
///
/// [last] bounds the date (its day is selectable); time precision is minutes.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(last) ? last : initial,
    firstDate: first,
    lastDate: last,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
