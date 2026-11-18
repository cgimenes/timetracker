import 'package:flutter/material.dart';

import '../theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/derived.dart';
import '../entry_actions.dart';
import '../format.dart';

/// A "Quick start" section listing the most used projects (the top
/// [quickStartCount] by frecency). Choosing one opens a modal with its last
/// accounts; choosing an account asks when to start it.
class QuickStart extends ConsumerWidget {
  const QuickStart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(quickStartProjectsProvider);
    if (projects.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('quick-start'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Quick start',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final project in projects)
              ListTile(
                contentPadding: trailingFilledButtonTilePadding,
                title: Text(project),
                onTap: () => _choose(context, ref, project),
                trailing: IconButton.filledTonal(
                  key: Key('quick-$project'),
                  tooltip: 'Choose...',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _choose(context, ref, project),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Shows the last accounts of [project]; the one picked goes to the Start
  /// dialog.
  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    String project,
  ) async {
    final account = await showDialog<String>(
      context: context,
      builder: (_) => _ProjectModal(project),
    );
    if (account == null || !context.mounted) return;
    await startAgain(context, ref, account);
  }
}

/// The last accounts of a project, newest first, with when each was last
/// started.
class _ProjectModal extends ConsumerWidget {
  const _ProjectModal(this.project);

  final String project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uses = ref.watch(projectRecentAccountsProvider(project));
    return SimpleDialog(
      key: const Key('quick-modal'),
      title: Text(project),
      children: [
        if (uses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('Everything in this project is running'),
          ),
        for (final u in uses)
          ListTile(
            key: Key('quick-account-${u.account}'),
            title: Text(u.account),
            subtitle: Text(formatDateTime(u.start)),
            onTap: () => Navigator.pop(context, u.account),
          ),
      ],
    );
  }
}
