import 'dart:convert';
import 'dart:typed_data';

import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'timeclock_storage.dart';

/// [TimeclockStorage] on a directory picked with the Storage Access Framework.
class SafTimeclockStorage implements TimeclockStorage {
  SafTimeclockStorage(this.treeUri, {SafUtil? util, SafStream? stream})
    : _util = util ?? SafUtil(),
      _stream = stream ?? SafStream();

  final String treeUri;
  final SafUtil _util;
  final SafStream _stream;

  // With text/plain the provider appends ".txt" to the name.
  static const _mime = 'application/octet-stream';

  @override
  Future<List<StoredFile>> list() async => [
    for (final f in await _util.list(treeUri))
      if (!f.isDir)
        StoredFile(
          f.name,
          f.length,
          DateTime.fromMillisecondsSinceEpoch(f.lastModified),
        ),
  ];

  @override
  Future<String?> read(String name) async {
    final file = await _util.child(treeUri, [name]);
    if (file == null || file.isDir) return null;
    return utf8.decode(await _stream.readFileBytes(file.uri));
  }

  @override
  Future<void> write(String name, String content) =>
      _put(name, content, overwrite: true);

  @override
  Future<void> append(String name, String content) =>
      _put(name, content, append: true);

  Future<void> _put(
    String name,
    String content, {
    bool overwrite = false,
    bool append = false,
  }) async {
    final saved = await _stream.writeFileBytes(
      treeUri,
      name,
      _mime,
      Uint8List.fromList(utf8.encode(content)),
      overwrite: overwrite,
      append: append,
    );
    // The provider renames on conflict; we would then lose track of the file.
    final savedAs = saved.fileName;
    if (savedAs != null && savedAs != name) {
      throw StateError('Provider saved "$name" as "$savedAs"');
    }
  }
}
