import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(const MaterialApp(home: SpikePage()));
}

const _prefKey = 'treeUri';
const _fileName = 'spike.timeclock';

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> with WidgetsBindingObserver {
  final _util = SafUtil();
  final _stream = SafStream();
  final _log = <String>[];
  String? _treeUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Simulates "external edits (sync) detected on resume".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _treeUri != null) {
      _run('resume: stat', _statFile);
    }
  }

  void _say(String msg) => setState(() => _log.insert(0, msg));

  Future<void> _run(String label, Future<void> Function() fn) async {
    final sw = Stopwatch()..start();
    try {
      await fn();
      _say('$label ok (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _say('$label FAILED: $e');
    }
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_prefKey);
    if (uri == null) return _say('no stored uri');
    final ok = await _util.hasPersistedPermission(
      uri,
      checkRead: true,
      checkWrite: true,
    );
    _say('restored uri, persisted permission = $ok');
    setState(() => _treeUri = ok ? uri : null);
  }

  Future<void> _pick() => _run('pick', () async {
    final dir = await _util.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    if (dir == null) throw 'cancelled';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, dir.uri);
    setState(() => _treeUri = dir.uri);
    _say('picked ${dir.name}');
  });

  Future<void> _append() => _run('append', () async {
    final line = 'i ${DateTime.now().toIso8601String()} spike:append\n';
    await _stream.writeFileBytes(
      _treeUri!,
      _fileName,
      'application/octet-stream',
      Uint8List.fromList(utf8.encode(line)),
      append: true,
    );
  });

  Future<void> _rewrite() => _run('rewrite', () async {
    final f = await _util.child(_treeUri!, [_fileName]);
    if (f == null) throw 'file missing';
    final text = utf8.decode(await _stream.readFileBytes(f.uri));
    final lines = text.split('\n')..removeWhere((l) => l.isEmpty);
    if (lines.isNotEmpty) lines.removeLast(); // "remove entry"
    final out = lines.isEmpty ? '' : '${lines.join('\n')}\n';
    await _stream.writeFileBytes(
      _treeUri!,
      _fileName,
      'application/octet-stream',
      Uint8List.fromList(utf8.encode(out)),
      overwrite: true,
    );
    _say('rewrote, ${lines.length} lines left');
  });

  Future<void> _read() => _run('read', () async {
    final f = await _util.child(_treeUri!, [_fileName]);
    if (f == null) throw 'file missing';
    final text = utf8.decode(await _stream.readFileBytes(f.uri));
    _say('content:\n$text');
  });

  Future<void> _list() => _run('list', () async {
    final files = await _util.list(_treeUri!);
    _say('files: ${files.map((f) => '${f.name}(${f.length}b)').join(', ')}');
  });

  Future<void> _statFile() async {
    final f = await _util.child(_treeUri!, [_fileName]);
    _say(
      f == null
          ? 'stat: missing'
          : 'stat: ${f.length}b mtime=${DateTime.fromMillisecondsSinceEpoch(f.lastModified)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _treeUri != null;
    return Scaffold(
      appBar: AppBar(title: const Text('SAF spike')),
      body: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(onPressed: _pick, child: const Text('Pick dir')),
              ElevatedButton(
                onPressed: enabled ? _append : null,
                child: const Text('Append'),
              ),
              ElevatedButton(
                onPressed: enabled ? _rewrite : null,
                child: const Text('Rewrite'),
              ),
              ElevatedButton(
                onPressed: enabled ? _read : null,
                child: const Text('Read'),
              ),
              ElevatedButton(
                onPressed: enabled ? _list : null,
                child: const Text('List'),
              ),
              ElevatedButton(
                onPressed: enabled
                    ? () => _run('start A', () => startEntry('work:acme:dev'))
                    : null,
                child: const Text('Start A'),
              ),
              ElevatedButton(
                onPressed: enabled
                    ? () => _run('start B', () => startEntry('work:acme:meet'))
                    : null,
                child: const Text('Start B'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                for (final l in _log)
                  Padding(padding: const EdgeInsets.all(4), child: Text(l)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
