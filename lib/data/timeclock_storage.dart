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

/// Flat directory of text files. The Android implementation sits on top of the
/// Storage Access Framework; tests use an in-memory one.
abstract interface class TimeclockStorage {
  /// Every file in the directory, whatever its extension.
  Future<List<StoredFile>> list();

  /// Text of the file, or null when it does not exist.
  Future<String?> read(String name);

  /// Creates the file or replaces its whole content.
  Future<void> write(String name, String content);

  /// Adds [content] at the end of the file, creating it when missing.
  Future<void> append(String name, String content);
}
