import 'package:flutter/material.dart';

import 'format.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Asks for a date and a time in one dialog. Null when the user cancels.
///
/// The date is picked with day chips (the last three days up to [last]) and
/// a calendar behind "Other date...". The time is picked on the Material
/// clock dial, opened from the time tile. Time precision is minutes.
///
/// [first] and [last] bound the date (both days are selectable). The dialog
/// refuses a moment after [notAfter] and one that is not after [after], and
/// says why, so the caller gets a valid answer.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  DateTime? notAfter,
  DateTime? after,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _DateTimeDialog(
    initial: initial,
    first: first,
    last: last,
    notAfter: notAfter,
    after: after,
  ),
);

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

class _DateTimeDialog extends StatefulWidget {
  const _DateTimeDialog({
    required this.initial,
    required this.first,
    required this.last,
    required this.notAfter,
    required this.after,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final DateTime? notAfter;
  final DateTime? after;

  @override
  State<_DateTimeDialog> createState() => _DateTimeDialogState();
}

class _DateTimeDialogState extends State<_DateTimeDialog> {
  late DateTime _date = _clamp(_day(widget.initial));
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.initial);
  late bool _calendarOpen = !_chipDays.contains(_date);

  /// The bounds, widened to hold the date being edited: an entry older than
  /// [first] keeps its date until the user picks another.
  DateTime get _first {
    final first = _day(widget.first);
    final initial = _day(widget.initial);
    return initial.isBefore(first) ? initial : first;
  }

  DateTime get _last {
    final last = _day(widget.last);
    final initial = _day(widget.initial);
    return initial.isAfter(last) ? initial : last;
  }

  DateTime _clamp(DateTime d) {
    if (d.isBefore(_first)) return _first;
    if (d.isAfter(_last)) return _last;
    return d;
  }

  /// Today, yesterday and the day before, those inside the bounds.
  List<DateTime> get _chipDays {
    final last = _last;
    final first = _first;
    return [
      for (var i = 0; i < 3; i++)
        if (!DateTime(last.year, last.month, last.day - i).isBefore(first))
          DateTime(last.year, last.month, last.day - i),
    ];
  }

  DateTime get _moment =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  String? get _error {
    final notAfter = widget.notAfter;
    if (notAfter != null && _moment.isAfter(notAfter)) return 'In the future';
    final after = widget.after;
    if (after != null && !_moment.isAfter(after)) {
      return 'Must be after the start';
    }
    return null;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Time',
      // The app writes 24 hour times everywhere.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  String _chipLabel(int index) => switch (index) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => '2 days ago',
  };

  @override
  Widget build(BuildContext context) {
    final chips = _chipDays;
    final onChip = chips.contains(_date);
    final scheme = Theme.of(context).colorScheme;
    final error = _error;
    // Chips go from today backwards; the labels follow that order.
    final last = _last;
    int indexOf(DateTime d) => last.difference(d).inDays;

    return AlertDialog(
      title: const Text('Date and time'),
      content: SizedBox(
        width: 328,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final d in chips)
                    ChoiceChip(
                      key: Key(switch (indexOf(d)) {
                        0 => 'dt-today',
                        1 => 'dt-yesterday',
                        _ => 'dt-2days',
                      }),
                      label: Text(_chipLabel(indexOf(d))),
                      selected: _date == d && !_calendarOpen,
                      onSelected: (_) => setState(() {
                        _date = d;
                        _calendarOpen = false;
                      }),
                    ),
                  ChoiceChip(
                    key: const Key('dt-other'),
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      onChip
                          ? 'Other date...'
                          : '${_weekdays[_date.weekday - 1]} ${formatDate(_date)}',
                    ),
                    selected: !onChip || _calendarOpen,
                    onSelected: (_) =>
                        setState(() => _calendarOpen = !_calendarOpen),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.topCenter,
                child: _calendarOpen
                    ? CalendarDatePicker(
                        key: const Key('dt-calendar'),
                        initialDate: _date,
                        firstDate: _first,
                        lastDate: _last,
                        onDateChanged: (d) => setState(() {
                          _date = d;
                          _calendarOpen = false;
                        }),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 12),
              Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('dt-time'),
                  onTap: _pickTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: scheme.primary),
                        const SizedBox(width: 16),
                        Text(
                          formatTimeOfDay(
                            DateTime(2000, 1, 1, _time.hour, _time.minute),
                          ),
                          key: const Key('dt-time-text'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Spacer(),
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error,
                    key: const Key('dt-error'),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('dt-ok'),
          onPressed: error == null
              ? () => Navigator.pop(context, _moment)
              : null,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
