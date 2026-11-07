import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';
import '../data/saf_timeclock_storage.dart';
import '../data/timeclock_repository.dart';
import 'running_content.dart';

/// Shows the running entries in the notification shade.
abstract interface class RunningNotifier {
  /// Posts, updates or removes the notification so it matches [running].
  Future<void> sync(List<StoredEntry> running);
}

const _notificationId = 100;
const _channelId = 'running';

final _plugin = FlutterLocalNotificationsPlugin();

/// Call once at startup, in the main isolate.
Future<void> initRunningNotifications() async {
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: handleNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: handleNotificationResponse,
  );
  await _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
}

/// One ongoing notification for all running entries.
///
/// There is no foreground service: Android 14+ lets users swipe those away
/// too. Instead, a swipe is reported on a background isolate and the
/// notification is posted again.
class LocalRunningNotifier implements RunningNotifier {
  const LocalRunningNotifier();

  @override
  Future<void> sync(List<StoredEntry> running) async {
    final content = buildRunningContent(running);
    if (content == null) {
      await _plugin.cancel(id: _notificationId);
      return;
    }
    await _plugin.show(
      id: _notificationId,
      title: content.title,
      body: content.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Running entries',
          channelDescription: 'Entries that are running right now',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          dismissIsolate: NotificationDismissedIsolate.background,
          showWhen: true,
          when: content.since.millisecondsSinceEpoch,
          usesChronometer: true,
          styleInformation: InboxStyleInformation(content.lines),
          actions: [
            for (final a in content.actions)
              AndroidNotificationAction(
                a.id,
                a.label,
                cancelNotification: false,
              ),
          ],
        ),
      ),
    );
  }
}

// Taps arrive in quick succession; each one reads and writes files.
Future<void> _queue = Future.value();

Future<void> _enqueue(Future<void> Function() job) {
  final next = _queue.then((_) => job());
  _queue = next.catchError(
    (Object _) {},
  ); // one failure must not block the rest
  return next;
}

/// Opens the repository on the stored folder without the UI or Riverpod, for
/// the background isolate. Null when the folder is gone.
Future<TimeclockRepository?> _openRepository() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // the main isolate may have saved a new folder
  final uri = await restoreTreeUri(prefs);
  return uri == null ? null : TimeclockRepository(SafTimeclockStorage(uri));
}

/// Handles taps on Stop and swipes of the notification. It runs on a
/// background isolate and also works when the app is not running.
@pragma('vm:entry-point')
Future<void> handleNotificationResponse(NotificationResponse response) =>
    _enqueue(() async {
      final repo = await _openRepository();
      if (repo == null) return;

      final account = accountFromActionId(response.actionId);
      try {
        if (account != null) {
          await repo.stopOldestRunning(account, DateTime.now());
        }
      } finally {
        // Also covers a swipe (nothing to stop): show the notification again.
        await const LocalRunningNotifier().sync((await repo.load()).running);
      }
    });
