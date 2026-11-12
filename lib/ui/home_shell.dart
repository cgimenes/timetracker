import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import 'budgets/budgets_page.dart';
import 'entries/entries_page.dart';
import 'metrics/metrics_page.dart';
import 'settings_page.dart';
import 'track/track_page.dart';

/// The tabs: Track, Entries, Metrics, Budgets (when enabled) and Settings.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

enum _Tab { track, entries, metrics, budgets, settings }

class _HomeShellState extends ConsumerState<HomeShell> {
  var _selected = _Tab.track;

  static const _pages = {
    _Tab.track: TrackPage(),
    _Tab.entries: EntriesPage(),
    _Tab.metrics: MetricsPage(),
    _Tab.budgets: BudgetsPage(),
    _Tab.settings: SettingsPage(),
  };

  static const _destinations = {
    _Tab.track: NavigationDestination(
      icon: Icon(Icons.timer_outlined),
      selectedIcon: Icon(Icons.timer),
      label: 'Track',
    ),
    _Tab.entries: NavigationDestination(
      icon: Icon(Icons.list_alt_outlined),
      selectedIcon: Icon(Icons.list_alt),
      label: 'Entries',
    ),
    _Tab.metrics: NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Metrics',
    ),
    _Tab.budgets: NavigationDestination(
      icon: Icon(Icons.savings_outlined),
      selectedIcon: Icon(Icons.savings),
      label: 'Budgets',
    ),
    _Tab.settings: NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(settingsProvider.select((s) => s.budgetsEnabled));
    final tabs = [
      for (final t in _Tab.values)
        if (t != _Tab.budgets || budgets) t,
    ];
    // Selection is by tab, not position, so turning Budgets on or off keeps
    // the user on the same screen (Settings, where the switch is).
    final selected = tabs.contains(_selected) ? _selected : _Tab.track;

    return Scaffold(
      // Keeps every tab alive, so a half-typed form survives a tab switch.
      body: IndexedStack(
        index: tabs.indexOf(selected),
        children: [
          for (final t in tabs)
            KeyedSubtree(key: ValueKey(t), child: _pages[t]!),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabs.indexOf(selected),
        onDestinationSelected: (i) => setState(() => _selected = tabs[i]),
        destinations: [for (final t in tabs) _destinations[t]!],
      ),
    );
  }
}
