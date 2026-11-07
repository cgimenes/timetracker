# Time tracker

Android time tracker that keeps your time in plain text files, in the
[timeclock format](https://hledger.org/time-planning.html) that hledger reads.
The files live in a folder you choose, so you can sync them with Syncthing,
Nextcloud or anything else, and query them with `hledger bal`.

The full behavior is in [spec.md](spec.md).

## What it does

- **Track:** start an entry (account with suggestions, optional backdated
  start) and see what is running. Several entries can run at once.
- **Notification:** one ongoing notification lists the running entries, with a
  Stop button for each. Stop works with the app closed.
- **Entries:** every entry by day, filtered by account level, with edit and
  remove.
- **Metrics:** time per account for today, this week and this month, grouped
  at the account depth you choose.
- **Settings:** the folder, how files are split (by day, week or month, and
  optionally by project) and the week start day.

## File format

```
i 2026-10-30 09:00:00 work:acme:dev
o 2026-10-30 12:30:00 work:acme:dev
```

The account is a colon separated path. A clock-out always repeats the account,
which is what lets entries overlap. Lines the app does not understand, comments
and blank lines are kept exactly as they are when it rewrites a file.

## Development

You need the Flutter SDK, the Android SDK and a phone or emulator.

```sh
flutter pub get
flutter analyze
flutter test                  # unit and widget tests, no device needed
flutter run                   # hot reload on a connected device
```

To install a build without `flutter run` (keeps the stored folder and its
permission, unlike uninstalling first):

```sh
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

The app icon comes from `assets/icon/`. After changing the images:

```sh
dart run flutter_launcher_icons
```

### Layout

| Path | What is there |
|---|---|
| `lib/core/` | Pure Dart: timeclock parsing and editing, metrics, frecency, file names, validation |
| `lib/data/` | Storage interface, the SAF (Android folder) implementation, the repository |
| `lib/settings/` | Settings and their persistence |
| `lib/state/` | Riverpod providers: entries, derived lists, clock |
| `lib/notifications/` | The running-entries notification and its background handler |
| `lib/ui/` | Screens: Track, Entries, Metrics, Settings |
| `test/` | Tests, with an in-memory storage in `test/support/` |
| `spikes/` | Throwaway experiments used to choose the stack, each with a `FINDINGS.md` |

### Notes

- The files are the only source of truth. The repository re-reads a file before
  every change and finds entries again by content, so a sync tool editing a
  file at the same time cannot make the app edit the wrong lines.
- Files are created with the MIME type `application/octet-stream`. With
  `text/plain`, Android adds a `.txt` extension.
- `flutter_local_notifications` is kept on 22.x: 23.x requires `compileSdk` 37,
  which the current Android Gradle Plugin does not support.
