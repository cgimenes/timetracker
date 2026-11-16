import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/navigation.dart';
import 'budgets/budgets_page.dart';
import 'calendar/calendar_page.dart';
import 'entries/entries_page.dart';
import 'metrics/metrics_page.dart';
import 'settings_page.dart';
import 'track/track_page.dart';

/// The screens, reached from tabs at the bottom. Settings is a cog in the
/// title bar.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _pages = {
    HomeTab.track: TrackPage(),
    HomeTab.entries: EntriesPage(),
    HomeTab.calendar: CalendarPage(),
    HomeTab.metrics: MetricsPage(),
    HomeTab.budgets: BudgetsPage(),
  };

  static const _items = {
    HomeTab.track: (Icons.timer_outlined, Icons.timer, 'Track'),
    HomeTab.entries: (Icons.list_alt_outlined, Icons.list_alt, 'Entries'),
    HomeTab.calendar: (
      Icons.calendar_today_outlined,
      Icons.calendar_today,
      'Calendar',
    ),
    HomeTab.metrics: (Icons.bar_chart_outlined, Icons.bar_chart, 'Metrics'),
    HomeTab.budgets: (Icons.flag_outlined, Icons.flag, 'Goals'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tabs = HomeTab.values;
    final selected = ref.watch(homeTabProvider);
    final index = tabs.indexOf(selected);

    return Scaffold(
      appBar: AppBar(
        title: Text(_items[selected]!.$3),
        actions: [
          IconButton(
            key: const Key('settings'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      // Keeps every screen alive, so a half-typed form survives a switch.
      body: IndexedStack(
        index: index,
        children: [
          for (final t in tabs)
            KeyedSubtree(key: ValueKey(t), child: _pages[t]!),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('tab-bar'),
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(homeTabProvider.notifier).select(tabs[i]),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(_items[t]!.$1),
              selectedIcon: Icon(_items[t]!.$2),
              label: _items[t]!.$3,
            ),
        ],
      ),
    );
  }
}
