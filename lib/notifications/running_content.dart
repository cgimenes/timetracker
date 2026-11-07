import '../core/timeclock.dart';
import '../data/timeclock_repository.dart';

/// Android shows at most three actions on a notification.
const maxStopActions = 3;

const _stopPrefix = 'stop:';

String stopActionId(String account) => '$_stopPrefix$account';

/// Account named by a Stop action, or null for any other action.
String? accountFromActionId(String? actionId) {
  if (actionId == null || !actionId.startsWith(_stopPrefix)) return null;
  final account = actionId.substring(_stopPrefix.length);
  return account.isEmpty ? null : account;
}

class StopAction {
  const StopAction(this.id, this.label);

  final String id;
  final String label;
}

/// What the running-entries notification shows.
class RunningContent {
  const RunningContent({
    required this.title,
    required this.body,
    required this.lines,
    required this.since,
    required this.actions,
  });

  final String title;
  final String body;

  /// One line per running entry, for the expanded view.
  final List<String> lines;

  /// Start of the oldest running entry: the chronometer counts from here.
  final DateTime since;

  /// A Stop button per running entry, oldest first, up to [maxStopActions].
  final List<StopAction> actions;
}

/// Content for [running], or null when nothing runs and the notification
/// should go away.
RunningContent? buildRunningContent(List<StoredEntry> running) {
  if (running.isEmpty) return null;
  final entries = running.map((s) => s.entry).toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  final hidden = entries.length - maxStopActions;
  return RunningContent(
    title: entries.length == 1
        ? entries.first.account
        : '${entries.length} running',
    body: entries.map((e) => e.account).join(', '),
    lines: [
      for (final e in entries) '${e.account} (since ${_hourMinute(e)})',
      if (hidden > 0) '+$hidden more, stop them in the app',
    ],
    since: entries.first.start,
    actions: [
      for (final e in entries.take(maxStopActions))
        StopAction(
          stopActionId(e.account),
          'Stop ${e.account.split(':').last}',
        ),
    ],
  );
}

String _hourMinute(Entry e) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(e.start.hour)}:${p(e.start.minute)}';
}

/// Identity of what the notification shows, to skip redundant updates.
String runningSignature(List<StoredEntry> running) => running
    .map((s) => '${s.entry.account}@${s.entry.start.millisecondsSinceEpoch}')
    .join('|');
