import 'account.dart';

/// Returns an error message, or null when the entry can be saved.
///
/// [end] null means the entry is running. Times in the future are rejected
/// because the app only records time that already happened.
String? validateEntry({
  required String account,
  required DateTime start,
  DateTime? end,
  String? comment,
  required DateTime now,
}) {
  final error = validateAccount(account) ?? validateComment(comment);
  if (error != null) return error;
  if (start.isAfter(now)) return 'Start is in the future';
  if (end != null) {
    if (!end.isAfter(start)) return 'End must be after start';
    if (end.isAfter(now)) return 'End is in the future';
  }
  return null;
}
