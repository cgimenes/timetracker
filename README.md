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
- **Entries:** finished entries by day, searched by account or comment, with edit and
  remove.
- **Metrics:** time per account for today, this week and this month, grouped
  at the account depth you choose.
- **Budgets:** optional tab. Hours per project for each day, week or month the
  files are split in, kept in `budget.journal` so `hledger bal --budget` reads
  them too. Progress shows in Metrics.
- **Settings:** the folder, how files are split (by day, week or month, and
  optionally by project, in the file name or in folders) and the week start day.

## File format

```
i 2026-10-30 09:00:00 work:acme:dev
o 2026-10-30 12:30:00 work:acme:dev
```

The account is a colon separated path. A clock-out always repeats the account,
which is what lets entries overlap. Lines the app does not understand, comments
and blank lines are kept exactly as they are when it rewrites a file.

Budgets live next to them in `budget.journal`:

```
~ monthly from 2026-10-01 to 2026-11-01
    (work)    40h
```

```sh
hledger -f budget.journal -f '*.timeclock' bal --budget -M --depth 1
```

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

### Releasing

CI (`.github/workflows/ci.yml`) runs format check, analyze, tests and a debug
build on every PR and push to `master`.

Releases are automated with
[Release Please](https://github.com/googleapis/release-please). Use
[Conventional Commits](https://www.conventionalcommits.org) (PR titles are
checked): `fix:` bumps patch, `feat:` bumps minor, `feat!:` or a
`BREAKING CHANGE:` footer bumps major. Release Please keeps a release PR open
that updates `CHANGELOG.md` and the `pubspec.yaml` version. Merging it tags
`vX.Y.Z`, creates the GitHub Release, and the workflow attaches a signed
`timetracker-vX.Y.Z.apk` plus its `.sha256`.

One-time setup:

```sh
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias timetracker
base64 -w0 release.jks    # value for ANDROID_KEYSTORE_BASE64
```

Add these repository secrets: `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Also
enable Settings > Actions > General > "Allow GitHub Actions to create and
approve pull requests". Back up the keystore: without it, installed apps cannot
be updated.

To sign a release build locally, create `android/key.properties` (git ignored):

```properties
storeFile=app/release.jks
storePassword=...
keyAlias=timetracker
keyPassword=...
```

Without that file, release builds fall back to the debug key.

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
