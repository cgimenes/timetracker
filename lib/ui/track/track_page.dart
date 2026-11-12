import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../state/entries.dart';
import '../choose_folder.dart';
import '../load_error.dart';
import 'add_entry_card.dart';
import 'daily_goals_card.dart';
import 'quick_start.dart';
import 'running_section.dart';

/// Start an entry and see what is running.
class TrackPage extends ConsumerWidget {
  const TrackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFolder = ref.watch(treeUriProvider) != null;
    final entries = hasFolder ? ref.watch(entriesProvider) : null;

    return Scaffold(
      body: SafeArea(
        child: !hasFolder
            ? const ChooseFolderPrompt()
            : RefreshIndicator(
                // Pull to read the files again, for example after a sync.
                onRefresh: () => ref.read(entriesProvider.notifier).reload(),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (entries!.hasError && !entries.hasValue)
                      LoadErrorCard(entries.error)
                    else ...[
                      const AddEntryCard(),
                      const QuickStart(),
                      const RunningSection(),
                      const DailyGoalsCard(),
                    ],
                  ].expand((w) => [w, const SizedBox(height: 12)]).toList(),
                ),
              ),
      ),
    );
  }
}
