# Changelog

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
