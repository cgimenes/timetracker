import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/frecency.dart';
import '../core/metrics.dart';
import '../data/timeclock_repository.dart';
import '../settings/app_settings.dart';
import 'clock.dart';
import 'entries.dart';

List<StoredEntry> _entries(Ref ref) =>
    ref.watch(entriesProvider).value?.entries ?? const [];

/// Running entries, newest first.
final runningProvider = Provider<List<StoredEntry>>(
  (ref) => _entries(ref).where((e) => e.entry.isRunning).toList(),
);

/// The three most recent finished entries.
final lastFinishedProvider = Provider<List<StoredEntry>>(
  (ref) => _entries(ref).where((e) => !e.entry.isRunning).take(3).toList(),
);

/// Time per account at the configured level, for Today, This week and This
/// month.
final metricsProvider = Provider.family<Metrics, PeriodKind>((ref, kind) {
  final now = nowOf(ref);
  final settings = ref.watch(settingsProvider);
  return computeMetrics(
    _entries(ref).map((e) => e.entry),
    periodRange(kind, now, weekStart: settings.weekStart),
    level: settings.metricsLevel,
    now: now,
  );
});

/// Accounts to suggest when starting an entry, best first.
final accountSuggestionsProvider = Provider<List<String>>(
  (ref) => rankAccounts(_entries(ref).map((e) => e.entry), nowOf(ref)),
);

/// Account to prefill in the add form.
final lastAccountProvider = Provider<String?>(
  (ref) => lastUsedAccount(_entries(ref).map((e) => e.entry)),
);

/// Problems found while reading the files (malformed lines, orphan clock-outs).
final warningsProvider = Provider<List<FileWarning>>(
  (ref) => ref.watch(entriesProvider).value?.warnings ?? const [],
);
