/// Readable name for a tree URI from the document picker, e.g.
/// `content://com.android.externalstorage.documents/tree/primary%3ADocuments%2Ftime`
/// becomes `Documents/time`. Falls back to the URI itself.
String friendlyFolderName(String treeUri) {
  final segments = Uri.tryParse(treeUri)?.pathSegments;
  if (segments == null) return treeUri;
  final at = segments.indexOf('tree');
  if (at < 0 || at + 1 >= segments.length) return treeUri;

  final id = segments[at + 1]; // `primary:Documents/time` or `1234-ABCD:time`
  final colon = id.indexOf(':');
  if (colon < 0) return id;
  final volume = id.substring(0, colon);
  final path = id.substring(colon + 1);
  if (volume == 'primary') return path.isEmpty ? 'Internal storage' : path;
  return path.isEmpty ? volume : '$volume: $path';
}
