# Flutter spike findings

Device: Samsung SM-S921B (Android 14+), Flutter 3.47.9.

## Result
Passed after fixes: SAF pick, persistence across restart, append, rewrite, list, external edit on resume. Notification path needed three fixes (MIME type, manifest receiver, desugaring), described below.

## SAF (saf_util + saf_stream)
- Pick directory with `persistablePermission: true`; URI stored in shared_preferences, `hasPersistedPermission` true after force-stop. Works.
- Append, overwrite, list, read work.
- Create files with MIME `application/octet-stream`. With `text/plain` the provider appends `.txt`.
- External edits visible via `lastModified`/`length` on resume.

## Notifications (flutter_local_notifications 22.x)
- Notification actions need `ActionBroadcastReceiver` declared manually in AndroidManifest (not merged from the plugin).
- `flutter_local_notifications` needs core library desugaring enabled in `android/app/build.gradle.kts`.
- Chronometer (`usesChronometer` + `when`) ticks without Dart running.
- Android allows max 3 actions per notification.
- Ongoing notifications and foreground-service notifications are swipeable on Android 14+, even with `NO_CLEAR`.
- A foreground service (`startForegroundService`, `specialUse`) was tried and works (actions update 1, 3, 2, 1 as entries start and stop), but its notification is still swipeable on Android 14+, so it adds nothing here.
- Chosen approach: single ongoing notification, `dismissIsolate: background` callback re-posts it on swipe. No foreground service.
- Running entries stored in shared_preferences so the background isolate can update the notification.
- Notification actions and dismiss run in a background isolate (top-level `@pragma('vm:entry-point')` function); it must not touch UI state.
- The spike never confirmed Stop with the app killed or the swipe re-post on the device. The real app (`lib/notifications/`) confirmed both on the same phone: Stop with the app dead, swipe re-post, and re-post at startup after a swipe while the app was closed. The background handler needed no extra plugin initialization.
- `flutter_local_notifications` 23.0.0 forces `compileSdk` 37 (via `androidx.core` 1.19); stay on 22.3.x while the project builds with AGP 9.1.

## Edit loop
- Hot reload (about 1s, state kept) was the reason for choosing Flutter; not timed in this session.
- `flutter run --no-resident` exited with a service-protocol error after install; the app still ran.

## Gotchas
- `flutter install` uninstalls the old app first (wipes prefs and SAF permission). Use `adb install -r`.
- Wireless adb sometimes needs `adb kill-server` before the device reappears.
