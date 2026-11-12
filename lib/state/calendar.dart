import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/account.dart';
import '../core/day_layout.dart';
import '../data/timeclock_repository.dart';
import '../settings/app_settings.dart';
import 'clock.dart';
import 'entries.dart';

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// The day shown in the Calendar, date only. Starts on today.
final calendarDayProvider = NotifierProvider<CalendarDayNotifier, DateTime>(
  CalendarDayNotifier.new,
);

class CalendarDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => _dayOf(ref.read(clockProvider)());

  void set(DateTime day) => state = _dayOf(day);

  void shift(int days) =>
      state = DateTime(state.year, state.month, state.day + days);

  void today() => state = _dayOf(ref.read(clockProvider)());
}

/// Entries drawn in the selected day, placed side by side where they overlap.
final calendarBlocksProvider = Provider<List<DayBlock<StoredEntry>>>((ref) {
  final day = ref.watch(calendarDayProvider);
  final now = ref.watch(nowProvider);
  final entries = ref.watch(entriesProvider).value?.entries ?? const [];
  return layoutDay<StoredEntry>(entries, (s) => s.entry, day, now);
});

/// Name that decides the color of an entry: the account cut to the Calendar
/// level.
String colorKey(String account, int level) => truncateAccount(account, level);

/// Stable color slot for each account group (the account cut to [level]), in
/// alphabetical order over every entry, so a group keeps its color from day
/// to day and no two groups share one until the palette is used up.
final groupColorSlotsProvider = Provider.family<Map<String, int>, int>((
  ref,
  level,
) {
  final entries = ref.watch(entriesProvider).value?.entries ?? const [];
  final names = {
    for (final e in entries) colorKey(e.entry.account, level),
  }.toList()..sort();
  return {for (var i = 0; i < names.length; i++) names[i]: i};
});

/// Level the Calendar colors by, from Settings.
final calendarLevelProvider = Provider<int>(
  (ref) => ref.watch(settingsProvider.select((s) => s.calendarLevel)),
);
