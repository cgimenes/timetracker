import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/budget.dart';
import '../../state/derived.dart';
import '../format.dart';
import '../palette.dart';

const _lineHeight = 150.0;
const _barHeight = 90.0;
const _axisWidth = 36.0;

double _hours(Duration d) => d.inSeconds / 3600;

/// Day by day pace of a goal: time done and time expected as lines, and how
/// far ahead or behind it is as bars.
class GoalPaceChart extends ConsumerWidget {
  const GoalPaceChart(this.budget, {super.key});

  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(goalPaceProvider(budget));
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    final doneColor = goalBarColor(achieved: false, brightness: brightness);
    final aheadColor = goalBarColor(achieved: true, brightness: brightness);
    final expectedColor = scheme.outline;
    final behindColor = scheme.error;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _lineHeight,
            child: LineChart(
              key: Key(
                'goal-pace-lines-${budget.window.label}-${budget.account}',
              ),
              _lines(context, days, doneColor, expectedColor),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _barHeight,
            child: BarChart(
              key: Key(
                'goal-pace-bars-${budget.window.label}-${budget.account}',
              ),
              _bars(context, days, aheadColor, behindColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Legend('Done', doneColor, style: textTheme.bodySmall),
                _Legend('Expected', expectedColor, style: textTheme.bodySmall),
                _Legend('Ahead', aheadColor, style: textTheme.bodySmall),
                _Legend('Behind', behindColor, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  FlTitlesData _titles(
    BuildContext context,
    List<PaceDay> days, {
    required bool showDays,
  }) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final step = days.length > 14 ? 5 : 1;
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _axisWidth,
          getTitlesWidget: (value, meta) =>
              value == meta.max || value == meta.min
              ? const SizedBox.shrink()
              : Text('${hoursLabel(value)}h', style: labelStyle),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: showDays,
          reservedSize: 24,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= days.length || i % step != 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${days[i].day.day}', style: labelStyle),
            );
          },
        ),
      ),
    );
  }

  LineChartData _lines(
    BuildContext context,
    List<PaceDay> days,
    Color doneColor,
    Color expectedColor,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final tooltipStyle = TextStyle(color: scheme.onInverseSurface);
    final top = [
      budget.amount,
      for (final d in days) ...[d.expected, ?d.current],
    ].map(_hours).fold(0.0, (a, b) => a > b ? a : b);

    return LineChartData(
      minY: 0,
      maxY: top <= 0 ? 1 : top * 1.1,
      minX: 0,
      maxX: (days.length - 1).toDouble(),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: scheme.outlineVariant, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: _titles(context, days, showDays: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => scheme.inverseSurface,
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(
                s.barIndex == 0
                    ? '${formatDate(days[s.spotIndex].day)}\n'
                          'Expected ${formatHm(days[s.spotIndex].expected)}'
                    : 'Done ${formatHm(days[s.x.toInt()].current!)}',
                tooltipStyle,
              ),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < days.length; i++)
              FlSpot(i.toDouble(), _hours(days[i].expected)),
          ],
          color: expectedColor,
          barWidth: 2,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: [
            for (var i = 0; i < days.length; i++)
              if (days[i].current != null)
                FlSpot(i.toDouble(), _hours(days[i].current!)),
          ],
          color: doneColor,
          barWidth: 3,
          dotData: FlDotData(show: days.length <= 14),
        ),
      ],
    );
  }

  BarChartData _bars(
    BuildContext context,
    List<PaceDay> days,
    Color aheadColor,
    Color behindColor,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final spread = [
      for (final d in days)
        if (d.difference != null) _hours(d.difference!).abs(),
    ].fold(0.0, (a, b) => a > b ? a : b);
    final limit = spread <= 0 ? 1.0 : spread * 1.1;

    return BarChartData(
      minY: -limit,
      maxY: limit,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: value == 0 ? scheme.outline : scheme.outlineVariant,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: _titles(context, days, showDays: true),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => scheme.inverseSurface,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final day = days[groupIndex];
            final diff = day.difference;
            if (diff == null) return null;
            return BarTooltipItem(
              '${formatDate(day.day)}\n${formatSignedHm(diff)}',
              TextStyle(color: scheme.onInverseSurface),
            );
          },
        ),
      ),
      barGroups: [
        for (var i = 0; i < days.length; i++)
          BarChartGroupData(
            x: i,
            barRods: [
              if (days[i].difference case final diff?)
                BarChartRodData(
                  toY: _hours(diff),
                  width: days.length > 14 ? 6 : 12,
                  color: diff.isNegative ? behindColor : aheadColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(diff.isNegative ? 0 : 3),
                    bottom: Radius.circular(diff.isNegative ? 3 : 0),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color, {this.style});

  final String label;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}
