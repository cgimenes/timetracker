import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/file_naming.dart';
import '../core/metrics.dart';
import '../data/providers.dart';
import '../settings/app_settings.dart';
import '../state/clock.dart';
import 'folder_name.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _template = TextEditingController(
    text: ref.read(settingsProvider).fileNameTemplate,
  );

  @override
  void dispose() {
    _template.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    try {
      await ref.read(treeUriProvider.notifier).pick();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not pick a folder: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final treeUri = ref.watch(treeUriProvider);
    final now = ref.watch(nowProvider);

    // A split change can replace the template; keep the field in line.
    ref.listen(settingsProvider.select((s) => s.fileNameTemplate), (_, t) {
      if (_template.text != t) _template.text = t;
    });

    final templateError = validateFileNameTemplate(
      _template.text,
      settings.split,
      byProject: settings.splitByProject,
    );
    final example = templateError == null
        ? fileNameFor(now, settings.split, _template.text, project: 'work')
        : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Files directory'),
              subtitle: Text(
                treeUri == null
                    ? 'Not chosen yet'
                    : friendlyFolderName(treeUri),
              ),
              trailing: TextButton(
                onPressed: _pickFolder,
                child: Text(treeUri == null ? 'Choose' : 'Change'),
              ),
            ),
            const Divider(),
            const _SectionTitle('Files'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<SplitMethod>(
                key: const Key('split'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: SplitMethod.none, label: Text('None')),
                  ButtonSegment(value: SplitMethod.day, label: Text('Day')),
                  ButtonSegment(value: SplitMethod.week, label: Text('Week')),
                  ButtonSegment(value: SplitMethod.month, label: Text('Month')),
                ],
                selected: {settings.split},
                onSelectionChanged: (s) => notifier.setSplit(s.first),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Starts a new file for each period. Existing files stay as they are.',
              ),
            ),
            SwitchListTile(
              key: const Key('split-by-project'),
              title: const Text('Split by project'),
              subtitle: const Text(
                'One file per first account level, for example work and personal.',
              ),
              value: settings.splitByProject,
              onChanged: notifier.setSplitByProject,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('template'),
                controller: _template,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'File name',
                  border: const OutlineInputBorder(),
                  errorText: templateError,
                  helperText: example == null ? null : 'Example: $example',
                  helperMaxLines: 2,
                ),
                onChanged: (text) {
                  // Only valid names are saved; the field shows the error.
                  setState(() {});
                  notifier.setFileNameTemplate(text);
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tokens: {yyyy} {MM} {dd} {ww} {project}. With {ww}, {yyyy} is the ISO week year.',
              ),
            ),
            const Divider(height: 32),
            const _SectionTitle('Metrics'),
            ListTile(
              title: const Text('Week starts on'),
              trailing: SegmentedButton<WeekStart>(
                key: const Key('week-start'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: WeekStart.monday, label: Text('Mon')),
                  ButtonSegment(value: WeekStart.sunday, label: Text('Sun')),
                ],
                selected: {settings.weekStart},
                onSelectionChanged: (s) => notifier.setWeekStart(s.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
