/// A file in the timeclock directory, as the storage reports it.
class StoredFile {
  const StoredFile(this.name, this.size, this.modified);

  final String name;
  final int size;
  final DateTime modified;

  @override
  bool operator ==(Object other) =>
      other is StoredFile &&
      other.name == name &&
      other.size == size &&
      other.modified == modified;

  @override
  int get hashCode => Object.hash(name, size, modified);

  @override
  String toString() => '$name ($size bytes, $modified)';
}

/// Directory of text files, with files one level down in project folders. The
/// Android implementation sits on top of the Storage Access Framework; tests
/// use an in-memory one.
///
/// A file is named by its path relative to the directory, with `/` between
/// the folder and the file: `time.timeclock` or `work/2026-10.timeclock`.
/// Writing a file creates its folder.
abstract interface class TimeclockStorage {
  /// Every file in the directory and in its folders (one level), whatever
  /// its extension.
  Future<List<StoredFile>> list();

  /// Text of the file, or null when it does not exist.
  Future<String?> read(String name);

  /// Creates the file or replaces its whole content.
  Future<void> write(String name, String content);

  /// Adds [content] at the end of the file, creating it when missing.
  Future<void> append(String name, String content);
}
