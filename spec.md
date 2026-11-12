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
- Projects (default Together): how the first account level (`work` in `work:acme:dev`) is told apart on disk.
  - Together: all projects share the same files.
  - File name: one file per project, combined with the split method: month gives `work-2026-10.timeclock`. Files stay in the one directory.
  - Folders: one folder per project, one level below the chosen directory: `work/2026-10.timeclock`. The folder is created when the first entry of the project is written. The file name template has no `{project}`.
  - Characters that are not safe in a file or folder name (`/ \ : * ? " < > |`, control characters, a leading dot) are replaced by `_` in the project part.
- Filename format: template with tokens `{yyyy}`, `{MM}`, `{dd}`, `{ww}` (ISO week) and `{project}`, extension `.timeclock`. When the template contains `{ww}`, `{yyyy}` is the ISO week year, so days at the turn of the year land in the right file (2027-01-01 is `2026-W53`). The template must contain every token needed to tell periods apart (day: `{yyyy}`, `{MM}`, `{dd}`; week: `{yyyy}`, `{ww}`; month: `{yyyy}`, `{MM}`), plus `{project}` when projects are in the file name. `{project}` is refused in the other modes. Default per split: `none` -> `time.timeclock`, `month` -> `{yyyy}-{MM}.timeclock`, etc.; with projects in the file name the default starts with `{project}-` (`none` -> `{project}.timeclock`). A template that is still the default follows the split method and the Projects setting; a custom one is kept only if it is valid for the new choice, otherwise it goes back to the default.
- Entry lives in file of its clock-in date (and project, when projects are split by file name or folder). Clock-out written to same file even if crossing split boundary. Editing an entry moves it to another file when its start leaves the period, or its first account level changes project (with project folders, to the other folder).
- Changing split method, project split or format affects new entries only; existing files not migrated (v1). App reads all `*.timeclock` files in the directory and in its folders (one level), whatever the current setting, so files written under an older layout stay visible.
- External edits (sync) detected on resume/focus; app reloads.
- Files are created with MIME type `application/octet-stream`. With `text/plain`, Android document providers append `.txt` (`time.timeclock` becomes `time.timeclock.txt`), and the app then fails to find its own files by name.

## UI

Screens: Track, Entries, Calendar, Metrics, Goals, Settings. They are reached from a side bar on the left.

- Narrow screens (under 600 dp): a top bar with a menu button and the screen name. The menu opens a drawer with the screens.
- Wide screens and landscape: a rail stays on the left, with no top bar. A menu button at its top collapses it to icons and expands it to icons with names. The choice is remembered.
- Only the Edit entry page, which is pushed over the screens, has its own header (it holds Save).
- Spacing: content sits 16 dp from the screen edges on both sides. Buttons and icons at the right end of a row are aligned so their visible edge is 16 dp from the edge, like the text on the left.

### Track

1. Add section
   - Account field: prefilled with last used account; dropdown history sorted by frecency; free text allowed.
   - Two buttons side by side, both disabled if account invalid, both close the keyboard:
     - Start now: clock-in at the current time.
     - Start at...: one dialog asks date and time (calendar plus hour and minute), and OK starts the entry at that time. A time in the future is refused.
   - Every date and time is asked in that one dialog (also Stop at... and Edit entry), never a date step followed by a time step.
   - No comment field. Comments already present in a file are kept when the app rewrites it, and shown on running entries.
   - Quick start: a section named "Quick start" under the form, listing the three accounts with the best frecency, one per row. Each row has a play button at its right end that starts that account now (the duplicate warning applies). Hidden when there is no history.
2. Running section
   - List of running entries: account, start, live elapsed time.
   - Each has a Stop icon button (a stop symbol, no label; clock-out at now) and a menu: Stop at... (custom time), Edit (the Edit entry page) and Cancel entry (after a confirmation, removes the entry and records no time).
3. Today section
   - Same as the Today group of Metrics (time per account today, total, running entries counted up to now), but always grouped at level 1 (by project), whatever the Metrics level is.
   - Daily goals: under the total, the daily goals set in Settings, one per project, with time done today / goal and a progress bar (yellow, green with a check once reached). They are not the goals of `budget.journal`, and show whether or not the Goals screen is on. None set: no section.

### Calendar

One day as a column of hours, like Google Calendar.

- Day selector: previous and next day arrows (next is off on today), the date (tap it to pick a day, nothing after today) and a Today button.
- 24 hour rows, scrolled to an hour above the first entry of the day (or above now on an empty today, or the morning). A red line marks the current time on today.
- Each entry is a block placed by time. Entries are clipped to the day, so one that crosses midnight shows on both days. A running entry ends at now. Entries that overlap share the width of the column evenly side by side.
- A block shows the account, the time range and the duration (account and duration only when it is short).
- Colors: a "Color by" control picks account level 1, 2 or 3 (saved). Entries of the same group (`work` at level 1, `work:acme` at level 2, `work:acme:dev` at level 3) share a color, and a legend above the column lists the groups of the day. The same group has the same color on every day.
- Zoom: pinch with two fingers, or use the + and - buttons over the column. The height of an hour goes from 28 to 168 px (default 56) and is remembered. Zooming keeps the time under the fingers in place. One finger still scrolls.
- Tap a block: a sheet with the entry details and its actions: Start again, Edit, Remove. A running entry has Edit and Cancel entry instead, like on Track.
- An empty day says "No entries".

### Metrics

- Level control (integer >= 1, default 1): totals are grouped by account depth. Level 2 turns `work:acme:dev` into `work:acme`.
- Chart at the bottom (after the three period groups): stacked bars of tracked time, one bar per day, week or month, chosen with a Day / Week / Month selector (not saved, starts on Day).
  - Day shows the last 14 days, Week the last 12 weeks (first day set by the week start setting, labeled by that day), Month the last 12 months. The last bar holds today.
  - Each bar is stacked by account group at the Level above, with the same colors as the Calendar. At most 8 groups are drawn, the rest are merged into "Other". A legend lists them.
  - Touching a bar shows its period, total and the time of each group. Entries crossing a boundary count only inside each bar; running entries count up to now.
  - No time in the range: "No time tracked" instead of the chart.
- Three groups: Today, This week, This month.
- Each lists sum of durations per account truncated to the level, sorted desc, plus total.
- Running entries count up to now.
- Entries crossing period boundary counted only for portion inside period.

### Goals

The Goals screen is always in the side bar (between Metrics and Settings), and goals show in Metrics.

- A goal is the time to reach for one project (first account level) in one day, week or month. Goals follow the file split: with month files the screen holds monthly goals, with week files weekly ones, with day files daily ones.
- Colors: a goal is yellow while in progress and green once achieved (time used reaches the target). An achieved goal also gets a check mark and green text, so the state does not depend on color alone. Going past the target is not a problem, so nothing turns red.
- Stored in `budget.journal` (hledger calls them budgets), in the same folder, as hledger periodic transactions bounded to their period (`to` is exclusive):

      ~ monthly from 2026-10-01 to 2026-11-01
          (work)    40h

      ~ weekly from 2026-10-26 to 2026-11-02
          (work)    10h

  hledger reads it with `hledger -f budget.journal -f '*.timeclock' bal --budget`. hledger weeks start on Monday, like the ISO weeks of the files, whatever the Metrics week start setting says.
- Blocks without dates (`~ monthly`) repeat every day, week or month. They are shown in "Every day / week / month" cards. With Split None there is no period to follow, so goals are only these repeating ones, and the period is chosen per goal.
- The app only understands `~ daily|weekly|monthly [from D to D]` blocks with `(project)  Nh` postings (N up to 2 decimals). Every other line is kept untouched when the app rewrites the file. Goals for sub-accounts are left alone. The file is not a timeclock file, so the app never reads it as entries.
- Goals screen: one card per window, newest first, plus the current one even when empty. Each card lists its goals with used / allowed time and a progress bar (yellow, or green when achieved). Tap a goal to edit it, use the trash icon to remove it (after a confirmation), and "Add goal" to add one to that window. "Goals for another period" picks a date and adds to the slice that holds it. This screen is the only place goals are configured.
- Used time is what the project tracked inside the window (running entries count up to now). A repeating goal is measured against the current day, week or month.
- Metrics: each period card lists the goals that apply now (the repeating ones and the one for the current slice) under "Goals", with the same colors. External edits are picked up on resume or pull to refresh.

### Notification

- One ongoing notification while at least one entry is running, shared by all running entries.
- Title: the account, or "N running" when several. Chronometer counts from the oldest running entry. Inbox lines list each account with its start time.
- Stop action per running entry (clock-out at now), at most 3 (Android limit). Entries beyond 3 are stopped from the app. Tapping the notification opens the app.
- Stop works with the app process dead.
- No foreground service. On Android 14+ users can swipe the notification away; the app re-posts it immediately (dismiss callback), and again on app open.
- Notification disappears when the last running entry stops.
- Requires notification permission (Android 13+); if denied, app works without it.

### Entries

- List all finished entries, newest first, grouped by day. Running entries are not listed (they are on Track); day totals count finished entries only.
- Search field above the list: keeps the entries whose account or comment contains every word typed, ignoring case. Day headers and totals follow the search. A clear button empties it.
- Each entry has a menu button (three dots) at the end of its row. Pressing it shows the actions in the same row, in place of the duration: Start again, Edit, Remove (icons), and the row gets a highlighted background. Tapping the row itself does nothing. One row is open at a time; pressing the menu button again, running an action or changing the search closes it.
  - Start again: asks "Now" or "Pick time" (the one date and time dialog), then clocks in the same account and switches to the Track screen, where it is running. No comment is copied. If the account already runs, the same duplicate warning as in Track is shown first.
  - Edit: account, start, end (end empty = running). Validation: end > start, nothing in the future. The entry's comment is kept as it is.
  - Remove: confirmation dialog.

### Settings

- Files directory (picker).
- File split method: none | day | week | month.
- Projects: together | file name | folders.
- Filename format (template, live preview of example filename).
- Week start day: Monday (default) | Sunday (used by the Metrics week).
- Daily goals: hours to reach every day, per project (add, edit, remove with a confirmation). Kept in the app preferences, never written to `budget.journal`. Shown in the Today section of Track.
- App version (`v1.3.0`), small and centered, at the end of the list. Read from the installed app with `package_info_plus`.

## Edge cases

- Same account started twice concurrently: allowed. Known limitation: hledger rejects overlapping sessions with the same account ("Overlapping sessions with the same account name are not supported"), so the file is not parseable by hledger until one session is stopped or edited. App shows a warning dialog before starting such entry. Clock-out of an ambiguous account closes the oldest running entry of that account; Running section Stop button targets the chosen entry, so app writes `o` lines ordered so each stops the intended session (oldest first when equal).
- Start time in future: reject.
- Clock-out before clock-in: reject.
- Orphan clock-out in file (no matching clock-in): show warning, ignore in metrics.
- Running entry left open for days: shown normally; metrics clip to period.
- Directory permission revoked or unavailable: if access was removed the app asks for a folder again; if the folder cannot be read (moved, deleted), Track, Entries and Metrics show a card with the error, "Try again" and "Choose another folder". Nothing is written until the files can be read.
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

## Open questions

- None.
