import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account.dart';
import '../../core/metrics.dart';
import '../../data/providers.dart';
import '../../settings/app_settings.dart';
import '../../state/budgets.dart';
import '../../state/derived.dart';
import '../../state/entries.dart';
import '../choose_folder.dart';
import '../load_error.dart';
import '../format.dart';

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
        bottom: false,
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
                      _PeriodCard(kind, title),
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

class _PeriodCard extends ConsumerWidget {
  const _PeriodCard(this.kind, this.title);

  final PeriodKind kind;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(metricsProvider(kind));
    final budgets = ref.watch(budgetProgressProvider(kind));
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: textTheme.titleMedium)),
                Text(
                  formatHm(metrics.total),
                  key: Key('total-${kind.name}'),
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            if (metrics.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No time tracked'),
              ),
            for (final row in metrics.rows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(row.account)),
                    Text(formatHm(row.duration)),
                  ],
                ),
              ),
            if (budgets.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Budgets', style: textTheme.titleSmall),
              for (final b in budgets) _BudgetRow(kind, b),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow(this.kind, this.progress);

  final PeriodKind kind;
  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = progress.over;
    final style = over ? TextStyle(color: scheme.error) : null;

    return Padding(
      key: Key('budget-${kind.name}-${progress.project}'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(progress.project)),
              Text(
                '${formatHm(progress.used)} / ${formatHm(progress.budget)}',
                style: style,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress.fraction,
            color: over ? scheme.error : null,
          ),
        ],
      ),
    );
  }
}
