# Android Time Tracker

Android app to track time as plain text in timeclock format, readable by hledger (`hledger -f file.timeclock bal`).

## Goals

- Plain text files user owns, stored in user chosen directory (syncable via Syncthing, Nextcloud, etc).
- Fast start/stop from phone.
- Quick overview of time per account.

Non goals (v1): cloud sync, multiple devices writing same file concurrently, invoicing, rates, home screen widget / quick settings tile, export or share from app.

## Glossary

- Entry: one session, clock-in line plus optional clock-out line.
- Running entry: entry with clock-in, no clock-out yet.
- Account: entry description, colon separated hierarchy, e.g. `work:acme:dev`.
- Level: account depth. Level 1 of `work:acme:dev` is `work`, level 2 is `work:acme`.
- Frecency: ranking by frequency of use weighted by recency.

## Data format

Timeclock, one line per event:

    i 2026-10-30 09:00:00 work:acme:dev  optional comment
    o 2026-10-30 12:30:00 work:acme:dev

Rules:

- Datetime format `YYYY-MM-DD HH:MM:SS`, local time.
- Clock-out line ALWAYS repeats account name (required for concurrent sessions in hledger; verify min hledger version supporting overlapping sessions).
- Account: non-empty, no leading/trailing spaces, no two consecutive spaces (hledger uses double space as separator), no `;`.
- Comment: optional, separated from account by two spaces.
- Lines appended in chronological order of event; edits rewrite file preserving order.
- Unknown/malformed lines preserved untouched on rewrite and reported as warning.

## File storage

- Directory chosen via Android storage picker; permission persisted.
- Split method: `none`, `day`, `week`, `month`.
- Filename format: template with tokens `{yyyy}`, `{MM}`, `{dd}`, `{ww}` (ISO week), extension `.timeclock`. When the template contains `{ww}`, `{yyyy}` is the ISO week year, so days at the turn of the year land in the right file (2027-01-01 is `2026-W53`). The template must contain every token needed to tell periods apart (day: `{yyyy}`, `{MM}`, `{dd}`; week: `{yyyy}`, `{ww}`; month: `{yyyy}`, `{MM}`). Default per split: `none` -> `time.timeclock`, `month` -> `{yyyy}-{MM}.timeclock`, etc.
- Entry lives in file of its clock-in date. Clock-out written to same file even if crossing split boundary.
- Changing split method or format affects new entries only; existing files not migrated (v1). App reads all files in directory matching any `*.timeclock`.
- External edits (sync) detected on resume/focus; app reloads.
- Files are created with MIME type `application/octet-stream`. With `text/plain`, Android document providers append `.txt` (`time.timeclock` becomes `time.timeclock.txt`), and the app then fails to find its own files by name.

## UI

Bottom tabs: Track, Entries, Metrics, Settings. Tabs have no top header; the bottom bar names the screen. Only the Edit entry page, which is pushed over the tabs, has a header (it holds Save).

### Track

1. Add section
   - Account field: prefilled with last used account; dropdown history sorted by frecency; free text allowed.
   - Start time: prefilled with now, editable (date + time).
   - Start button. Disabled if account invalid.
   - No comment field. Comments already present in a file are kept when the app rewrites it, and shown on running entries.
2. Running section
   - List of running entries: account, start, live elapsed time.
   - Each has Stop button (clock-out at now) and option to stop at custom time.

### Metrics

- Level control (integer >= 1, default 1): totals are grouped by account depth. Level 2 turns `work:acme:dev` into `work:acme`.
- Three groups: Today, This week, This month.
- Each lists sum of durations per account truncated to the level, sorted desc, plus total.
- Running entries count up to now.
- Entries crossing period boundary counted only for portion inside period.

### Notification

- One ongoing notification while at least one entry is running, shared by all running entries.
- Title: the account, or "N running" when several. Chronometer counts from the oldest running entry. Inbox lines list each account with its start time.
- Stop action per running entry (clock-out at now), at most 3 (Android limit). Entries beyond 3 are stopped from the app. Tapping the notification opens the app.
- Stop works with the app process dead.
- No foreground service. On Android 14+ users can swipe the notification away; the app re-posts it immediately (dismiss callback), and again on app open.
- Notification disappears when the last running entry stops.
- Requires notification permission (Android 13+); if denied, app works without it.

### Entries

- List all entries, newest first, grouped by day.
- Filter by level: select level, then account prefix at that level.
- Each entry menu: Edit, Remove.
  - Edit: account, start, end (end empty = running). Validation: end > start, nothing in the future. The entry's comment is kept as it is.
  - Remove: confirmation dialog.

### Settings

- Files directory (picker).
- File split method: none | day | week | month.
- Filename format (template, live preview of example filename).
- Week start day: Monday (default) | Sunday (used by the Metrics week).

## Edge cases

- Same account started twice concurrently: allowed. Known limitation: hledger rejects overlapping sessions with the same account ("Overlapping sessions with the same account name are not supported"), so the file is not parseable by hledger until one session is stopped or edited. App shows a warning dialog before starting such entry. Clock-out of an ambiguous account closes the oldest running entry of that account; Running section Stop button targets the chosen entry, so app writes `o` lines ordered so each stops the intended session (oldest first when equal).
- Start time in future: reject.
- Clock-out before clock-in: reject.
- Orphan clock-out in file (no matching clock-in): show warning, ignore in metrics.
- Running entry left open for days: shown normally; metrics clip to period.
- Directory permission revoked or unavailable: banner, block writes, keep data in memory until resolved.
- DST change: store local time as written; durations computed with timezone aware conversion.

## Acceptance criteria

- Starting entry appends `i` line to correct file; stopping appends matching `o` line with account.
- `hledger -f <file> bal` on produced files returns same totals as the Metrics tab for the same period and depth (excluding files with overlapping same-account sessions).
- Starting an entry whose account is already running shows a warning about hledger incompatibility and proceeds only on confirmation.
- Notification lists running entries, each with a Stop action that clocks out at now; notification disappears when no entry is running.
- Two concurrent entries both stopped independently produce valid file for hledger.
- Editing/removing entry rewrites file, preserving untouched lines byte for byte.
- Account history suggestions ordered by frecency.
- Changing the level on the Metrics tab regroups the totals immediately.

## Technical considerations

### Stack

**Flutter**, chosen for developer experience (hot reload with only the CLI and an editor). Spikes of Flutter, Jetpack Compose and Expo tested persisted folder access (SAF) and the notification on a physical device. Results and gotchas are in each spike's `FINDINGS.md`: `spikes/flutter`, `spikes/compose`, `spikes/expo-spike`.

Libraries:

- SAF: `saf_util` (pick directory with persistable permission, list, stat) and `saf_stream` (read, append, overwrite).
- Notifications: `flutter_local_notifications` with `ActionBroadcastReceiver` declared in `AndroidManifest.xml` and core library desugaring enabled in `android/app/build.gradle.kts`.
- Notification actions and dismiss callbacks run in a background isolate: top-level `@pragma('vm:entry-point')` function, no UI state, all state read from shared preferences.
- Settings and the running list: `shared_preferences`.

## Planned later

Not part of the current implementation.

### Split files by project

Option to also split files by project, where the project is the first level of the account (`work` in `work:acme:dev`). It combines with the period split: for example month and project give `work/2026-10.timeclock`, or `work-2026-10.timeclock` if subdirectories are not wanted.

Open details to settle when this is built:

- Filename template token for the project (for example `{project}`), validation that it is present when the option is on, and whether the project may contain characters that are not valid in file names (`/`, spaces).
- Where the file lives (flat name or a directory per project), since the storage layer currently reads a flat directory.
- Entry lives in the file of its clock-in date and project. Editing the account's first level moves the entry to another file, the same way changing the start date across periods does today.
- Like the other split settings, it affects new entries only; existing files are not migrated.
- Settings gets a switch for it, next to the split method.

## Open questions

- None.
