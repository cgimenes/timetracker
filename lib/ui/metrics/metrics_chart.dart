import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../settings/app_settings.dart';
import '../../state/calendar.dart';
import '../../state/derived.dart';
import '../format.dart';
import '../palette.dart';

/// Series shown before the rest are merged into "Other".
const maxSeries = 8;
const otherSeries = 'Other';

/// Stacked bars of tracked time per day, week or month, one color per
/// account group (cut to the Metrics level).
class MetricsChart extends ConsumerWidget {
  const MetricsChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouping = ref.watch(chartGroupingProvider);
    final buckets = ref.watch(chartBucketsProvider);
    final level = ref.watch(settingsProvider.select((s) => s.metricsLevel));
    final slots = ref.watch(groupColorSlotsProvider(level));
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    final series = chartSeries(buckets);
    Color colorOf(String name) => name == otherSeries
        ? scheme.outline
        : paletteColor(slots[name] ?? 0, brightness);
    final empty = buckets.every((b) => b.total == Duration.zero);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Time', style: textTheme.titleMedium)),
                SegmentedButton<Grouping>(
                  key: const Key('chart-grouping'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: Grouping.day, label: Text('Day')),
                    ButtonSegment(value: Grouping.week, label: Text('Week')),
                    ButtonSegment(value: Grouping.month, label: Text('Month')),
                  ],
                  selected: {grouping},
                  onSelectionChanged: (s) =>
                      ref.read(chartGroupingProvider.notifier).set(s.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (empty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No time tracked')),
              )
            else
              SizedBox(
                height: 220,
                child: BarChart(
                  key: const Key('chart'),
                  _data(context, buckets, series, colorOf),
                ),
              ),
            if (!empty && series.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  key: const Key('chart-legend'),
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final name in series)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colorOf(name),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(name, style: textTheme.bodySmall),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  BarChartData _data(
    BuildContext context,
    List<Bucket> buckets,
    List<String> series,
    Color Function(String) colorOf,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final merged = [for (final b in buckets) mergeSeries(b, series)];
    final maxHours =
        merged
            .map((m) => m.values.fold(Duration.zero, (a, d) => a + d).inSeconds)
            .fold(0, (a, b) => a > b ? a : b) /
        3600;
    final top = maxHours <= 0 ? 1.0 : maxHours * 1.1;

    return BarChartData(
      maxY: top,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: scheme.outlineVariant, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) => value == meta.max
                ? const SizedBox.shrink()
                : Text('${_hoursLabel(value)}h', style: labelStyle),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(buckets[i].label, style: labelStyle),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => scheme.inverseSurface,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final bucket = buckets[groupIndex];
            final lines = merged[groupIndex].entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            return BarTooltipItem(
              '${_title(bucket)}  ${formatHm(bucket.total)}',
              TextStyle(
                color: scheme.onInverseSurface,
                fontWeight: FontWeight.w600,
              ),
              children: [
                for (final l in lines)
                  TextSpan(
                    text: '\n${l.key}  ${formatHm(l.value)}',
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      barGroups: [
        for (var i = 0; i < buckets.length; i++)
          BarChartGroupData(
            x: i,
            barRods: [
              () {
                var from = 0.0;
                final items = <BarChartRodStackItem>[];
                for (final name in series) {
                  final d = merged[i][name];
                  if (d == null || d == Duration.zero) continue;
                  final to = from + d.inSeconds / 3600;
                  items.add(BarChartRodStackItem(from, to, colorOf(name)));
                  from = to;
                }
                return BarChartRodData(
                  toY: from,
                  width: buckets.length > 12 ? 10 : 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                  rodStackItems: items,
                  color: Colors.transparent,
                );
              }(),
            ],
          ),
      ],
    );
  }

  String _hoursLabel(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

  String _title(Bucket b) {
    final start = b.range.start;
    return '${formatDate(start)}'
        '${b.range.end.difference(start).inDays > 1 ? ' ...' : ''}';
  }
}

/// The groups to draw, biggest first. More than [maxSeries] are cut and the
/// rest are drawn as [otherSeries].
List<String> chartSeries(List<Bucket> buckets) {
  final totals = <String, Duration>{};
  for (final b in buckets) {
    b.byAccount.forEach((k, v) => totals[k] = (totals[k] ?? Duration.zero) + v);
  }
  final names = totals.keys.toList()
    ..sort((a, b) {
      final byTime = totals[b]!.compareTo(totals[a]!);
      return byTime != 0 ? byTime : a.compareTo(b);
    });
  if (names.length <= maxSeries) return names;
  return [...names.take(maxSeries), otherSeries];
}

/// The bucket's time per drawn series, folding the groups that were cut into
/// "Other".
Map<String, Duration> mergeSeries(Bucket bucket, List<String> series) {
  final out = <String, Duration>{};
  bucket.byAccount.forEach((name, d) {
    final key = series.contains(name) ? name : otherSeries;
    out[key] = (out[key] ?? Duration.zero) + d;
  });
  return out;
}
