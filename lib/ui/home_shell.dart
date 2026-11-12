import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
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

enum _Tab { track, entries, calendar, metrics, budgets, settings }

/// Width from which the side bar stays on screen.
const _wideBreakpoint = 600.0;

class _HomeShellState extends ConsumerState<HomeShell> {
  var _selected = _Tab.track;

  static const _pages = {
    _Tab.track: TrackPage(),
    _Tab.entries: EntriesPage(),
    _Tab.calendar: CalendarPage(),
    _Tab.metrics: MetricsPage(),
    _Tab.budgets: BudgetsPage(),
    _Tab.settings: SettingsPage(),
  };

  static const _items = {
    _Tab.track: (Icons.timer_outlined, Icons.timer, 'Track'),
    _Tab.entries: (Icons.list_alt_outlined, Icons.list_alt, 'Entries'),
    _Tab.calendar: (
      Icons.calendar_today_outlined,
      Icons.calendar_today,
      'Calendar',
    ),
    _Tab.metrics: (Icons.bar_chart_outlined, Icons.bar_chart, 'Metrics'),
    _Tab.budgets: (Icons.savings_outlined, Icons.savings, 'Budgets'),
    _Tab.settings: (Icons.settings_outlined, Icons.settings, 'Settings'),
  };

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(settingsProvider.select((s) => s.budgetsEnabled));
    final expanded = ref.watch(
      settingsProvider.select((s) => s.sideBarExpanded),
    );
    final tabs = [
      for (final t in _Tab.values)
        if (t != _Tab.budgets || budgets) t,
    ];
    // Selection is by tab, not position, so turning Budgets on or off keeps
    // the user on the same screen (Settings, where the switch is).
    final selected = tabs.contains(_selected) ? _selected : _Tab.track;
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
                    setState(() => _selected = tabs[i]),
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
          setState(() => _selected = tabs[i]);
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
