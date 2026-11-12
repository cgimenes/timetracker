import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account.dart';
import '../../core/metrics.dart';
import '../../data/providers.dart';
import '../../settings/app_settings.dart';
import '../../state/budgets.dart';
import '../../state/entries.dart';
import '../choose_folder.dart';
import '../load_error.dart';
import 'metrics_chart.dart';
import 'period_card.dart';

/// Time per account for Today, This week and This month, grouped at the
/// level chosen here.
class MetricsPage extends ConsumerWidget {
  const MetricsPage({super.key});

  static const _periods = [
    (PeriodKind.today, 'Today'),
    (PeriodKind.week, 'This week'),
    (PeriodKind.month, 'This month'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFolder = ref.watch(treeUriProvider) != null;
    final entries = hasFolder ? ref.watch(entriesProvider) : null;

    return Scaffold(
      body: SafeArea(
        child: !hasFolder
            ? const ChooseFolderPrompt()
            : RefreshIndicator(
                onRefresh: () => Future.wait([
                  ref.read(entriesProvider.notifier).reload(),
                  ref.read(budgetsProvider.notifier).reload(),
                ]),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (entries!.hasError && !entries.hasValue)
                      LoadErrorCard(entries.error),
                    const _LevelCard(),
                    for (final (kind, title) in _periods)
                      PeriodCard(kind, title),
                    const MetricsChart(),
                  ].expand((w) => [w, const SizedBox(height: 12)]).toList(),
                ),
              ),
      ),
    );
  }
}

/// How deep accounts are grouped: level 2 turns `work:acme:dev` into
/// `work:acme`.
class _LevelCard extends ConsumerWidget {
  const _LevelCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(settingsProvider.select((s) => s.metricsLevel));
    final notifier = ref.read(settingsProvider.notifier);

    return Card(
      child: ListTile(
        title: const Text('Level'),
        subtitle: Text(
          'Totals are grouped by account depth. '
          'work:acme:dev at level $level is ${truncateAccount('work:acme:dev', level)}.',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('level-minus'),
              icon: const Icon(Icons.remove),
              onPressed: level > 1
                  ? () => notifier.setMetricsLevel(level - 1)
                  : null,
            ),
            Text('$level', key: const Key('level')),
            IconButton(
              key: const Key('level-plus'),
              icon: const Icon(Icons.add),
              onPressed: () => notifier.setMetricsLevel(level + 1),
            ),
          ],
        ),
      ),
    );
  }
}
