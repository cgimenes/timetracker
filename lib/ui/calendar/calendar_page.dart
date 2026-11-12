import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day_layout.dart';
import '../../data/providers.dart';
import '../../data/timeclock_repository.dart';
import '../../settings/app_settings.dart';
import '../../state/calendar.dart';
import '../../state/clock.dart';
import '../../state/entries.dart';
import '../choose_folder.dart';
import '../entry_actions.dart';
import '../format.dart';
import '../load_error.dart';
import '../palette.dart';

const _gutter = 52.0;
const _minBlockHeight = 22.0;

/// Factor of one zoom button press.
const _zoomStep = 1.25;
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// One day as a column of hours, like Google Calendar: entries are blocks
/// placed by time, side by side where they overlap, colored by account.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFolder = ref.watch(treeUriProvider) != null;
    final entries = hasFolder ? ref.watch(entriesProvider) : null;

    return Scaffold(
      body: SafeArea(
        child: !hasFolder
            ? const ChooseFolderPrompt()
            : entries!.hasError && !entries.hasValue
            ? ListView(
                padding: const EdgeInsets.all(12),
                children: [LoadErrorCard(entries.error)],
              )
            : const Column(
                children: [
                  _DayBar(),
                  _Legend(),
                  Expanded(child: _Timeline()),
                ],
              ),
      ),
    );
  }
}

class _DayBar extends ConsumerWidget {
  const _DayBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(calendarDayProvider);
    final today = ref.watch(nowProvider);
    final notifier = ref.read(calendarDayProvider.notifier);
    final level = ref.watch(calendarLevelProvider);
    final isToday = formatDate(day) == formatDate(today);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('cal-prev'),
                tooltip: 'Previous day',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => notifier.shift(-1),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('cal-date'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: day,
                      firstDate: DateTime(today.year - 5),
                      lastDate: DateTime(today.year, today.month, today.day),
                    );
                    if (picked != null) notifier.set(picked);
                  },
                  child: Text(
                    '${_weekdays[day.weekday - 1]} ${formatDate(day)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                key: const Key('cal-next'),
                tooltip: 'Next day',
                icon: const Icon(Icons.chevron_right),
                onPressed: isToday ? null : () => notifier.shift(1),
              ),
              TextButton(
                key: const Key('cal-today'),
                onPressed: isToday ? null : notifier.today,
                child: const Text('Today'),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 8),
              Text('Color by', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 12),
              SegmentedButton<int>(
                key: const Key('cal-level'),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 1, label: Text('Level 1')),
                  ButtonSegment(value: 2, label: Text('Level 2')),
                  ButtonSegment(value: 3, label: Text('Level 3')),
                ],
                selected: {level},
                onSelectionChanged: (s) => ref
                    .read(settingsProvider.notifier)
                    .setCalendarLevel(s.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Groups that appear on the selected day, with their colors.
class _Legend extends ConsumerWidget {
  const _Legend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(calendarLevelProvider);
    final slots = ref.watch(groupColorSlotsProvider(level));
    final blocks = ref.watch(calendarBlocksProvider);
    final brightness = Theme.of(context).brightness;
    final names = {
      for (final b in blocks) colorKey(b.entry.account, level),
    }.toList()..sort();
    if (names.isEmpty) return const SizedBox(height: 8);

    return Padding(
      key: const Key('cal-legend'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final name in names)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: paletteColor(slots[name] ?? 0, brightness),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(name, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }
}

class _Timeline extends ConsumerStatefulWidget {
  const _Timeline();

  @override
  ConsumerState<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<_Timeline> {
  late final ScrollController _scroll;

  /// Pointers on the screen. Two fingers zoom instead of scrolling.
  var _pointers = 0;
  var _pinching = false;
  var _pinchBase = defaultHourHeight;

  /// Scroll offset to apply after the next layout, while zooming.
  double? _pendingOffset;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _startOffset());
    // Another day: show its first entry.
    ref.listenManual(calendarDayProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(
          math.min(_startOffset(), _scroll.position.maxScrollExtent),
        );
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _hourHeight() => ref.read(settingsProvider).calendarHourHeight;

  /// Sets the zoom, keeping the time at [focalY] (a position in the visible
  /// part of the column) where it is.
  void _zoomTo(double height, {double? focalY}) {
    final old = _hourHeight();
    final next = height.clamp(minHourHeight, maxHourHeight);
    if (next == old) return;
    if (_scroll.hasClients) {
      final fy = focalY ?? _scroll.position.viewportDimension / 2;
      final offset = _pendingOffset ?? _scroll.offset;
      _pendingOffset = (offset + fy) * next / old - fy;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _pendingOffset;
        _pendingOffset = null;
        if (!mounted || target == null || !_scroll.hasClients) return;
        _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
      });
    }
    ref.read(settingsProvider.notifier).setCalendarHourHeight(next);
  }

  /// An hour above the first entry of the day, or above now for an empty
  /// today, or the morning.
  double _startOffset() {
    final blocks = ref.read(calendarBlocksProvider);
    final day = ref.read(calendarDayProvider);
    final now = ref.read(clockProvider)();
    double minute;
    if (blocks.isNotEmpty) {
      minute = blocks.map((b) => b.startMinute).reduce(math.min);
    } else if (formatDate(day) == formatDate(now)) {
      minute = now.hour * 60.0;
    } else {
      minute = 8 * 60;
    }
    return math.max(0, (minute - 60) / 60 * _hourHeight());
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(calendarDayProvider);
    final now = ref.watch(nowProvider);
    final blocks = ref.watch(calendarBlocksProvider);
    final level = ref.watch(calendarLevelProvider);
    final slots = ref.watch(groupColorSlotsProvider(level));
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isToday = formatDate(day) == formatDate(now);
    final hourHeight = ref.watch(
      settingsProvider.select((s) => s.calendarHourHeight),
    );

    final column = SingleChildScrollView(
      controller: _scroll,
      physics: _pinching ? const NeverScrollableScrollPhysics() : null,
      child: SizedBox(
        height: 24 * hourHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth - _gutter - 8;
            return Stack(
              children: [
                for (var h = 0; h < 24; h++) ...[
                  Positioned(
                    top: h * hourHeight,
                    left: 0,
                    width: _gutter,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Text(
                        '${h.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  Positioned(
                    top: h * hourHeight,
                    left: _gutter,
                    right: 0,
                    child: Divider(height: 1, color: scheme.outlineVariant),
                  ),
                ],
                if (blocks.isEmpty)
                  const Positioned.fill(
                    left: _gutter,
                    child: Align(
                      alignment: Alignment(0, -0.3),
                      child: Text('No entries'),
                    ),
                  ),
                for (final b in blocks)
                  _BlockView(
                    b,
                    hourHeight: hourHeight,
                    color: paletteColor(
                      slots[colorKey(b.entry.account, level)] ?? 0,
                      brightness,
                    ),
                    left: _gutter + width * b.column / b.columns,
                    width: width / b.columns - 2,
                  ),
                if (isToday)
                  Positioned(
                    key: const Key('cal-now'),
                    top: (now.hour * 60 + now.minute) / 60 * hourHeight,
                    left: _gutter - 4,
                    right: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(height: 2, color: scheme.error),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    return Stack(
      children: [
        Listener(
          onPointerDown: (_) {
            _pointers++;
            if (_pointers >= 2 && !_pinching) setState(() => _pinching = true);
          },
          onPointerUp: (_) => _released(),
          onPointerCancel: (_) => _released(),
          child: GestureDetector(
            onScaleStart: (_) => _pinchBase = _hourHeight(),
            onScaleUpdate: (d) {
              if (d.pointerCount >= 2) {
                _zoomTo(_pinchBase * d.scale, focalY: d.localFocalPoint.dy);
              }
            },
            child: column,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                key: const Key('cal-zoom-in'),
                heroTag: 'cal-zoom-in',
                tooltip: 'Zoom in',
                onPressed: hourHeight >= maxHourHeight
                    ? null
                    : () => _zoomTo(_hourHeight() * _zoomStep),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                key: const Key('cal-zoom-out'),
                heroTag: 'cal-zoom-out',
                tooltip: 'Zoom out',
                onPressed: hourHeight <= minHourHeight
                    ? null
                    : () => _zoomTo(_hourHeight() / _zoomStep),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _released() {
    if (_pointers > 0) _pointers--;
    if (_pointers < 2 && _pinching) setState(() => _pinching = false);
  }
}

class _BlockView extends ConsumerWidget {
  const _BlockView(
    this.block, {
    required this.hourHeight,
    required this.color,
    required this.left,
    required this.width,
  });

  final DayBlock<StoredEntry> block;
  final double hourHeight;
  final Color color;
  final double left;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = block.entry;
    final minutes = block.endMinute - block.startMinute;
    final height = math.max(minutes / 60 * hourHeight, _minBlockHeight);
    final fg = onPalette(color);
    final duration = formatHm(block.end.difference(block.start));
    final range = entry.isRunning
        ? '${formatTimeOfDay(entry.start)}, running'
        : '${formatTimeOfDay(entry.start)} to ${formatTimeOfDay(entry.end!)}';
    final small = height < 40;

    return Positioned(
      key: ValueKey('cal-block-${block.item.fileName}:${entry.inIndex}'),
      top: block.startMinute / 60 * hourHeight,
      left: left,
      width: width,
      height: height,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showActions(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: DefaultTextStyle(
              style: TextStyle(color: fg, fontSize: 12, height: 1.2),
              child: small
                  ? Text(
                      '${entry.account}  $duration',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.account,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$range, $duration',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final stored = block.item;
    final entry = stored.entry;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.account,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                entry.isRunning
                    ? 'since ${formatDateTime(entry.start)}, running'
                    : formatRange(entry.start, entry.end!),
              ),
              if (entry.comment != null) Text(entry.comment!),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (!entry.isRunning)
                    OutlinedButton.icon(
                      key: const Key('cal-restart'),
                      icon: const Icon(Icons.replay),
                      label: const Text('Start again'),
                      onPressed: () => Navigator.pop(context, 'restart'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('cal-edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    onPressed: () => Navigator.pop(context, 'edit'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('cal-remove'),
                    icon: Icon(
                      entry.isRunning
                          ? Icons.cancel_outlined
                          : Icons.delete_outline,
                    ),
                    label: Text(entry.isRunning ? 'Cancel entry' : 'Remove'),
                    onPressed: () => Navigator.pop(context, 'remove'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'restart':
        await restartEntry(context, ref, stored);
      case 'edit':
        editEntry(context, stored);
      default:
        if (entry.isRunning) {
          await cancelRunningEntry(context, ref, stored);
        } else {
          await confirmRemoveEntry(context, ref, stored);
        }
    }
  }
}
