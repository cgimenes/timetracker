import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import '../state/navigation.dart';
import 'budgets/budgets_page.dart';
import 'calendar/calendar_page.dart';
import 'entries/entries_page.dart';
import 'metrics/metrics_page.dart';
import 'settings_page.dart';
import 'track/track_page.dart';

/// The screens, reached from a side bar: a drawer on phones, a rail that
/// collapses to icons on wide screens.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

/// Width from which the side bar stays on screen.
const _wideBreakpoint = 600.0;

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _pages = {
    HomeTab.track: TrackPage(),
    HomeTab.entries: EntriesPage(),
    HomeTab.calendar: CalendarPage(),
    HomeTab.metrics: MetricsPage(),
    HomeTab.budgets: BudgetsPage(),
    HomeTab.settings: SettingsPage(),
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
    HomeTab.settings: (Icons.settings_outlined, Icons.settings, 'Settings'),
  };

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(
      settingsProvider.select((s) => s.sideBarExpanded),
    );
    const tabs = HomeTab.values;
    final selected = ref.watch(homeTabProvider);
    final index = tabs.indexOf(selected);

    // Keeps every screen alive, so a half-typed form survives a switch.
    final body = IndexedStack(
      index: index,
      children: [
        for (final t in tabs) KeyedSubtree(key: ValueKey(t), child: _pages[t]!),
      ],
    );

    if (MediaQuery.sizeOf(context).width >= _wideBreakpoint) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                key: const Key('side-rail'),
                extended: expanded,
                selectedIndex: index,
                onDestinationSelected: (i) =>
                    ref.read(homeTabProvider.notifier).select(tabs[i]),
                leading: IconButton(
                  key: const Key('side-toggle'),
                  tooltip: expanded ? 'Collapse' : 'Expand',
                  icon: Icon(expanded ? Icons.menu_open : Icons.menu),
                  onPressed: () => ref
                      .read(settingsProvider.notifier)
                      .setSideBarExpanded(!expanded),
                ),
                destinations: [
                  for (final t in tabs)
                    NavigationRailDestination(
                      icon: Icon(_items[t]!.$1),
                      selectedIcon: Icon(_items[t]!.$2),
                      label: Text(_items[t]!.$3),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_items[selected]!.$3)),
      drawer: NavigationDrawer(
        key: const Key('side-drawer'),
        selectedIndex: index,
        onDestinationSelected: (i) {
          ref.read(homeTabProvider.notifier).select(tabs[i]);
          Navigator.of(context).pop();
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 24, 16, 12),
            child: Text('Time tracker'),
          ),
          for (final t in tabs)
            NavigationDrawerDestination(
              icon: Icon(_items[t]!.$1),
              selectedIcon: Icon(_items[t]!.$2),
              label: Text(_items[t]!.$3),
            ),
        ],
      ),
      body: body,
    );
  }
}
