# Changelog

## [1.7.0](https://github.com/cgimenes/timetracker/compare/timetracker-v1.6.0...timetracker-v1.7.0) (2026-11-12)


### Features

* color the calendar by account level 3 ([4031c6f](https://github.com/cgimenes/timetracker/commit/4031c6fd05af896b9f3665c7efa5995f24368c5e))
* go to the track screen after starting an entry again ([2cd3fdb](https://github.com/cgimenes/timetracker/commit/2cd3fdb8c8c9cc0c9bf32715f8759c9318f01c10))
* menu button on each entry instead of tapping the row ([8eaece4](https://github.com/cgimenes/timetracker/commit/8eaece48c57b8b73cf1036d07f51df063464cc49))
* move the chart to the end of the metrics screen ([426f8cc](https://github.com/cgimenes/timetracker/commit/426f8cc52861cd2b46fb3a38c03d6df3ef301cfc))
* quick start buttons for the three most used accounts ([230056c](https://github.com/cgimenes/timetracker/commit/230056c36cbe1e0b3d562fd4b2f6c1802e2a27a7))
* zoom the calendar ([23ad239](https://github.com/cgimenes/timetracker/commit/23ad239707cac6643f317a8cb2ceea5d4616db82))


### Bug Fixes

* keep the bottom of every screen clear of the system bars ([e6388bb](https://github.com/cgimenes/timetracker/commit/e6388bbe02c2be177cf76ba0eb79fe93facee317))

## [1.6.0](https://github.com/cgimenes/timetracker/compare/timetracker-v1.5.0...timetracker-v1.6.0) (2026-11-12)


### Features

* calendar screen with a day column ([fc214d7](https://github.com/cgimenes/timetracker/commit/fc214d712e9a9b2a959360d4656354c6f4a8248a))
* chart of tracked time by day, week or month ([d0463fc](https://github.com/cgimenes/timetracker/commit/d0463fc162631f9b7666bac47a56277ef5774a49))
* replace the tabs with a collapsible side bar ([4148bc5](https://github.com/cgimenes/timetracker/commit/4148bc50f96fe4f5807273600b4a97c6cf8009ab))

## [1.5.0](https://github.com/cgimenes/timetracker/compare/timetracker-v1.4.0...timetracker-v1.5.0) (2026-11-12)


### Features

* edit or cancel a running entry from the track tab ([3a5b8de](https://github.com/cgimenes/timetracker/commit/3a5b8def1d74fb771d54ff4390db6888526c768d))
* show the app version at the end of settings ([801e19d](https://github.com/cgimenes/timetracker/commit/801e19d2de9c6336331316f53093ee4378a729a7))

## [1.4.0](https://github.com/cgimenes/timetracker/compare/timetracker-v1.3.0...timetracker-v1.4.0) (2026-11-12)


### Features

* search entries instead of filtering by level and prefix ([e3cd827](https://github.com/cgimenes/timetracker/commit/e3cd82742fe0e2920837574b8af549b34c44550f))


### Bug Fixes

* ask before removing a budget ([4d8235a](https://github.com/cgimenes/timetracker/commit/4d8235a52561a3bc9e5306d64c12d926c88284f7))
* remove the placeholders from the budget dialog ([e3401eb](https://github.com/cgimenes/timetracker/commit/e3401ebefe45584379154f4d4ed1394fd3531e8c))
* spacing in the date and time dialog ([dfce0eb](https://github.com/cgimenes/timetracker/commit/dfce0eb004b386c51ca89544eb98442b1e537c46))

## [1.3.0](https://github.com/cgimenes/timetracker/compare/timetracker-v1.2.0...timetracker-v1.3.0) (2026-11-12)


### Features

* budgets per file period, set in a new Budgets tab ([e5bcd50](https://github.com/cgimenes/timetracker/commit/e5bcd50b7aff2992a5fbb13c97b209fc85d2aa55))
* hide running entries from the entries tab ([e851906](https://github.com/cgimenes/timetracker/commit/e851906c6013406c223bc44090e3de4de0222f46))
* option to split projects into folders instead of file names ([63ff15a](https://github.com/cgimenes/timetracker/commit/63ff15a0efffaf469fcddd02c8d28f2da528e3c7))
* show entry actions inline when a row is tapped ([bd7af0c](https://github.com/cgimenes/timetracker/commit/bd7af0cdb4702958d0d5f296f09e7c50bb6f8d12))

## [1.2.0](https://github.com/cgimenes/timetracker/compare/timetracker-v1.1.0...timetracker-v1.2.0) (2026-11-12)


### Features

* per project budgets stored as hledger periodic transactions ([4d62691](https://github.com/cgimenes/timetracker/commit/4d626916d5d5fcb77ac7740f8e4420c65dac574b))
* pick date and time in one dialog ([7396c40](https://github.com/cgimenes/timetracker/commit/7396c402cee1b350a590cb26624f751583bbc193))
* start an entry again from the entries page ([76a0e58](https://github.com/cgimenes/timetracker/commit/76a0e58c603a7e29abf651ce7e7cd5bb1bef3a0a))
* start now or at a custom time from side by side buttons ([8f05a02](https://github.com/cgimenes/timetracker/commit/8f05a02ac2c92932b74d7429f233a5ec7a82e3d9))

## [1.1.0](https://github.com/cgimenes/timetracker/compare/timetracker-v1.0.0...timetracker-v1.1.0) (2026-11-07)


### Features

* first version with release ([028f299](https://github.com/cgimenes/timetracker/commit/028f29938f74a6bc5ea5f7cfefb4a4588421adf2))

## 1.0.0 (2026-11-06)

### Features

* Track: start entries with account suggestions and optional backdated start; several entries can run at once
* Ongoing notification listing running entries, with a Stop button for each (works with the app closed)
* Entries: list by day, filter by account level, edit and remove
* Metrics: time per account for today, this week and this month, grouped by chosen depth
* Settings: storage folder, file split by day, week or month (optionally by project), week start day
* Plain text storage in hledger timeclock format
