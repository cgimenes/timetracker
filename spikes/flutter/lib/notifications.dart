import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _treeUriKey = 'treeUri';
const _runningKey = 'running'; // List<String> of "epochMs|account"
const _fileName = 'spike.timeclock';
const _stopPrefix = 'stop:';
const _notificationId = 100;
const _maxActions = 3; // Android limit

final _plugin = FlutterLocalNotificationsPlugin();

String _stamp(DateTime t) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${p(t.month)}-${p(t.day)} ${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
}

Future<SharedPreferences> _prefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // other isolate may have written
  return prefs;
}

Future<void> _appendLine(SharedPreferences prefs, String line) async {
  final uri = prefs.getString(_treeUriKey);
  if (uri == null) return;
  await SafStream().writeFileBytes(
    uri,
    _fileName,
    'application/octet-stream',
    Uint8List.fromList(utf8.encode(line)),
    append: true,
  );
}

({int start, String account}) _parse(String s) {
  final i = s.indexOf('|');
  return (start: int.parse(s.substring(0, i)), account: s.substring(i + 1));
}

/// Single ongoing notification for all running entries.
/// Posts, updates or cancels it according to the stored running list.
/// Swiping it away is reported on the background isolate, which re-posts it.
Future<void> _syncNotification(SharedPreferences prefs) async {
  final running = (prefs.getStringList(_runningKey) ?? []).map(_parse).toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  if (running.isEmpty) {
    await _plugin.cancel(id: _notificationId);
    return;
  }

  await _plugin.show(
    id: _notificationId,
    title: running.length == 1
        ? running.first.account
        : '${running.length} running',
    body: running.map((e) => e.account).join(', '),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'running',
        'Running entries',
        channelDescription: 'Running time entries',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        dismissIsolate: NotificationDismissedIsolate.background,
        showWhen: true,
        when: running.first.start, // oldest entry
        usesChronometer: true,
        styleInformation: InboxStyleInformation([
          for (final e in running)
            '${e.account} (since ${_stamp(DateTime.fromMillisecondsSinceEpoch(e.start)).substring(11, 16)})',
        ]),
        actions: [
          for (final e in running.take(_maxActions))
            AndroidNotificationAction(
              '$_stopPrefix${e.account}',
              'Stop ${e.account.split(':').last}',
              cancelNotification: false,
            ),
        ],
      ),
    ),
  );
}

// Runs in a background isolate, possibly with the UI process dead.
@pragma('vm:entry-point')
Future<void> onNotificationResponse(NotificationResponse r) async {
  if (r.notificationResponseType ==
      NotificationResponseType.notificationDismissed) {
    await _syncNotification(await _prefs()); // swiped away: bring it back
    return;
  }
  final id = r.actionId;
  if (id == null || !id.startsWith(_stopPrefix)) return;
  final account = id.substring(_stopPrefix.length);
  await stopEntry(account);
}

Future<void> initNotifications() async {
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: onNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: onNotificationResponse,
  );
  await _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
}

Future<void> startEntry(String account) async {
  final prefs = await _prefs();
  final now = DateTime.now();
  await _appendLine(prefs, 'i ${_stamp(now)} $account\n');
  final running = prefs.getStringList(_runningKey) ?? [];
  await prefs.setStringList(_runningKey, [
    ...running,
    '${now.millisecondsSinceEpoch}|$account',
  ]);
  await _syncNotification(prefs);
}

Future<void> stopEntry(String account) async {
  final prefs = await _prefs();
  final running = prefs.getStringList(_runningKey) ?? [];
  final idx = running.indexWhere((s) => _parse(s).account == account);
  if (idx < 0) return;
  await _appendLine(prefs, 'o ${_stamp(DateTime.now())} $account\n');
  await prefs.setStringList(_runningKey, [...running]..removeAt(idx));
  await _syncNotification(prefs);
}
