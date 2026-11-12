import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/validation.dart';
import '../data/timeclock_repository.dart';
import '../state/clock.dart';
import '../state/derived.dart';
import '../state/entries.dart';
import 'date_time_dialog.dart';

export 'date_time_dialog.dart' show pickDateTime;

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
    notAfter: now,
  );
  if (picked == null || !context.mounted) return null;
  // The dialog already refuses the future; this is a safety net.
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
