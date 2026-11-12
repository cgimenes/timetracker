import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'notifications/providers.dart';
import 'state/budgets.dart';
import 'state/entries.dart';

/// Things that must keep running whatever screen is open: keeping the
/// notification in line with the running entries, and reading the files again
/// when the app returns to the foreground (a sync tool or the notification's
/// Stop button may have changed them).
class AppLifecycle extends ConsumerStatefulWidget {
  const AppLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends ConsumerState<AppLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(treeUriProvider) != null) {
      ref.read(entriesProvider.notifier).reloadIfChanged();
      ref.read(budgetsProvider.notifier).reloadIfChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationSyncProvider);
    return widget.child;
  }
}
