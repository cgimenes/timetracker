# Jetpack Compose spike findings

Device: Samsung SM-S921B (Android 14+). AGP 9.1.0, Kotlin 2.4.0, Compose BOM 2026.09.00, plain Gradle (no Android Studio).

## Result
Everything in the checklist passed with no workarounds: pick folder, persisted permission after force-stop, append, rewrite, list, external edit visible on resume, notification with chronometer and Stop actions, Stop with app killed, swipe re-post.

## SAF
- `ActivityResultContracts.OpenDocumentTree` + `contentResolver.takePersistableUriPermission` (read and write). Check with `persistedUriPermissions`.
- `DocumentFile` for `findFile`, `createFile`, `listFiles`, `length`, `lastModified`.
- Append with `openOutputStream(uri, "wa")`, overwrite with `"wt"`.
- Create files with MIME `application/octet-stream`. With `text/plain` the provider appends `.txt`.

## Notification
- Platform `Notification.Builder`: `setOngoing`, `setUsesChronometer` + `setWhen`, `InboxStyle`, up to 3 actions.
- Stop actions and `setDeleteIntent` target a `BroadcastReceiver`. Use `goAsync()` and a coroutine for the SAF write. Works with the app process dead, no engine or isolate.
- Swipe re-post: the delete intent triggers a re-post of the same notification. Needed because Android 14+ lets users dismiss ongoing and foreground-service notifications.
- Running list stored in `SharedPreferences`, shared by activity and receiver.

## Build notes
- Compose BOM 2026.x needs `compileSdk = 37`; AGP 9.1.0 recommends 36 max. Set `android.suppressUnsupportedCompileSdk=37` in `gradle.properties`. Older BOMs (2026.04 to 2026.06) also needed 37.
- `android.builtInKotlin=false` and `android.newDsl=false` copied from the Flutter template; AGP warns they go away in 10.0.
- `android.R.drawable.ic_menu_recent_history` is the correct name (not `ic_menu_recent`).
- Gradle wrapper copied from the Flutter template (Gradle 9.3.1).

## Edit loop
- CLI: `./gradlew installDebug` took about 11s from a one-string edit to the app running, with an app restart (UI state lost).
- Android Studio Live Edit (about 1s, no restart) is documented but was not tested here.

## Gotchas
- The phone was visible over USB and Wi-Fi at once; use `adb -s <serial>`.
- Use `adb install -r` (update) to keep the stored folder and permission.
