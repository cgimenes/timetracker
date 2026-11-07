import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/entries.dart';
import 'running_content.dart';
import 'running_notifier.dart';

/// Overridden in tests with a fake.
final runningNotifierProvider = Provider<RunningNotifier>(
  (ref) => const LocalRunningNotifier(),
);

/// Keeps the notification in line with the running entries. Watch it once,
/// near the root of the app.
///
/// Nothing happens until the files have been read, so a slow start never
/// removes a notification that is still valid. It fires once the first load
/// finishes, so a notification swiped away while the app was closed comes
/// back.
final notificationSyncProvider = Provider<void>((ref) {
  final notifier = ref.watch(runningNotifierProvider);
  String? shown;
  ref.listen(entriesProvider, (_, next) {
    final loaded = next.value;
    if (loaded == null) return;
    final signature = runningSignature(loaded.running);
    if (signature == shown) return;
    shown = signature;
    notifier.sync(loaded.running);
  }, fireImmediately: true);
});
