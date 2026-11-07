import 'package:timetracker/data/timeclock_storage.dart';

/// In-memory [TimeclockStorage]. Every change bumps the modified time, like a
/// real file system would.
class MemoryStorage implements TimeclockStorage {
  MemoryStorage([Map<String, String> files = const {}]) {
    files.forEach((name, content) => _files[name] = content);
  }

  final _files = <String, String>{};
  final _modified = <String, DateTime>{};
  var _tick = 0;

  /// What a sync tool or an editor would do to the directory.
  void externalWrite(String name, String content) => _set(name, content);

  void externalDelete(String name) {
    _files.remove(name);
    _modified.remove(name);
  }

  String? text(String name) => _files[name];

  Set<String> get names => _files.keys.toSet();

  void _set(String name, String content) {
    _files[name] = content;
    _modified[name] = DateTime.utc(2026).add(Duration(seconds: ++_tick));
  }

  @override
  Future<List<StoredFile>> list() async => [
    for (final e in _files.entries)
      StoredFile(e.key, e.value.length, _modified[e.key] ?? DateTime.utc(2026)),
  ];

  @override
  Future<String?> read(String name) async => _files[name];

  @override
  Future<void> write(String name, String content) async => _set(name, content);

  @override
  Future<void> append(String name, String content) async =>
      _set(name, (_files[name] ?? '') + content);
}
