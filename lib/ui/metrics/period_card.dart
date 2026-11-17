import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../state/derived.dart';
import '../format.dart';

/// Time per account for one period.
class PeriodCard extends ConsumerWidget {
  const PeriodCard(this.kind, this.title, {super.key});

  final PeriodKind kind;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(metricsProvider(kind));
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
          ],
        ),
      ),
    );
  }
}
