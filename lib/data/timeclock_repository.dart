import '../core/account.dart';
import '../core/file_naming.dart';
import '../core/timeclock.dart';
import 'timeclock_storage.dart';

/// How entries are spread over files (Settings).
class FileSettings {
  const FileSettings(
    this.split,
    this.template, {
    this.splitByProject = false,
    this.projectFolders = false,
  });

  factory FileSettings.defaults(
    SplitMethod split, {
    bool splitByProject = false,
    bool projectFolders = false,
  }) => FileSettings(
    split,
    defaultFileNameTemplate(split, byProject: splitByProject),
    splitByProject: splitByProject,
    projectFolders: projectFolders,
  );

  final SplitMethod split;
  final String template;

  /// Entries of different projects (first account level) go to different
  /// files. The template then has `{project}`.
  final bool splitByProject;

  /// Entries of different projects go to different folders, one level below
  /// the chosen directory. The template has no `{project}` then.
  final bool projectFolders;

  /// File that holds an entry of [account] that starts on [date], as a path
  /// relative to the chosen directory (`work/2026-10.timeclock` with project
  /// folders).
  String nameFor(DateTime date, String account) {
    final project = projectOf(account);
    final name = fileNameFor(date, split, template, project: project);
    return projectFolders ? '${safeFileNamePart(project)}/$name' : name;
  }
}

/// An entry together with the file it lives in.
class StoredEntry {
  const StoredEntry(this.fileName, this.entry);

  final String fileName;
  final Entry entry;
}

class FileWarning {
  const FileWarning(this.fileName, this.warning);

  final String fileName;
  final TimeclockWarning warning;

  @override
  String toString() => '$fileName, $warning';
}

/// Everything read from the directory at one moment.
class LoadResult {
  const LoadResult({
    required this.files,
    required this.entries,
    required this.warnings,
  });

  /// Timeclock files with the state they had when read.
  final List<StoredFile> files;

  /// All entries, newest first.
  final List<StoredEntry> entries;
  final List<FileWarning> warnings;

  List<StoredEntry> get running =>
      entries.where((e) => e.entry.isRunning).toList(growable: false);
}

/// The entry changed (or vanished) in its file after it was loaded, typically
/// because a sync tool rewrote the file. Reload and try again.
class StaleEntryException implements Exception {
  const StaleEntryException(this.fileName);

  final String fileName;

  @override
  String toString() => 'Entry changed in $fileName since it was loaded';
}

/// Reads and writes entries across the timeclock files.
///
/// Nothing is cached. Every change re-reads the target file, so a file edited
/// from outside between load and save is never overwritten with old content,
/// and entries are found again by content, not by line number.
class TimeclockRepository {
  const TimeclockRepository(this._storage);

  final TimeclockStorage _storage;

  Future<LoadResult> load() async {
    final files = (await _storage.list())
        .where((f) => isTimeclockFile(f.name))
        .toList();
    final entries = <StoredEntry>[];
    final warnings = <FileWarning>[];
    for (final file in files) {
      final text = await _storage.read(file.name);
      if (text == null) continue; // deleted since list()
      final doc = TimeclockDocument.parse(text);
      entries.addAll(doc.entries.map((e) => StoredEntry(file.name, e)));
      warnings.addAll(doc.warnings.map((w) => FileWarning(file.name, w)));
    }
    entries.sort((a, b) {
      final byStart = b.entry.start.compareTo(a.entry.start);
      if (byStart != 0) return byStart;
      final byFile = b.fileName.compareTo(a.fileName);
      return byFile != 0 ? byFile : b.entry.inIndex.compareTo(a.entry.inIndex);
    });
    return LoadResult(files: files, entries: entries, warnings: warnings);
  }

  /// True when the directory differs from [previous]: a file was added,
  /// removed or modified (for example by a sync tool).
  Future<bool> hasChanged(LoadResult previous) async {
    final now = (await _storage.list())
        .where((f) => isTimeclockFile(f.name))
        .toSet();
    return now.length != previous.files.length ||
        !now.containsAll(previous.files);
  }

  /// Clocks in, in the file of [start].
  Future<void> startEntry(
    String account,
    DateTime start, {
    String? comment,
    required FileSettings settings,
  }) => _update(
    settings.nameFor(start, account),
    (doc) => doc.startEntry(account, start, comment: comment),
  );

  /// Clocks out [stored] in the file where it clocked in.
  Future<void> stopEntry(StoredEntry stored, DateTime time) => _update(
    stored.fileName,
    (doc) => doc.stopEntry(_find(doc, stored), time),
  );

  /// Clocks out the oldest running entry of [account], wherever it is.
  /// Returns false when none is running. Meant for the notification action,
  /// which only knows the account.
  Future<bool> stopOldestRunning(String account, DateTime time) async {
    final running =
        (await load()).running.where((s) => s.entry.account == account).toList()
          ..sort((a, b) => a.entry.start.compareTo(b.entry.start));
    if (running.isEmpty) return false;
    await stopEntry(running.first, time);
    return true;
  }

  /// Changes all fields of [stored].
  ///
  /// The entry stays in its file unless the new start falls in another period
  /// than the old one under [settings]; then it moves to the file of the new
  /// start. Settings that changed since the entry was written do not move it.
  Future<void> replaceEntry(
    StoredEntry stored, {
    required String account,
    required DateTime start,
    DateTime? end,
    String? comment,
    required FileSettings settings,
  }) async {
    final target = settings.nameFor(start, account);
    final moves =
        target != settings.nameFor(stored.entry.start, stored.entry.account) &&
        target != stored.fileName;

    if (!moves) {
      return _update(
        stored.fileName,
        (doc) => doc.replaceEntry(
          _find(doc, stored),
          account: account,
          start: start,
          end: end,
          comment: comment,
        ),
      );
    }
    // Add first, then remove: a failure in between leaves a duplicate, never
    // a lost entry.
    await _update(
      target,
      (doc) => doc.addEntry(account, start, end: end, comment: comment),
    );
    await removeEntry(stored);
  }

  Future<void> removeEntry(StoredEntry stored) =>
      _update(stored.fileName, (doc) => doc.removeEntry(_find(doc, stored)));

  /// Finds the entry again in a freshly read document.
  Entry _find(TimeclockDocument doc, StoredEntry stored) {
    final wanted = stored.entry;
    for (final e in doc.entries) {
      if (e.account == wanted.account &&
          e.start == wanted.start &&
          e.end == wanted.end &&
          e.comment == wanted.comment) {
        return e;
      }
    }
    throw StaleEntryException(stored.fileName);
  }

  Future<void> _update(
    String fileName,
    TimeclockDocument Function(TimeclockDocument doc) change,
  ) async {
    final old = await _storage.read(fileName) ?? '';
    final next = change(TimeclockDocument.parse(old)).serialize();
    if (next == old) return;
    // Appending touches only the new lines, which is safer with sync tools
    // than rewriting the whole file.
    if (old.isNotEmpty && next.startsWith(old)) {
      await _storage.append(fileName, next.substring(old.length));
    } else {
      await _storage.write(fileName, next);
    }
  }
}
