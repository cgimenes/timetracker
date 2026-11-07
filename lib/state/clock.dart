import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of the current time. Tests override it with a fixed time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The current time, refreshed every second so running timers and metrics
/// stay live.
final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);

class NowNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => state = clock(),
    );
    ref.onDispose(timer.cancel);
    return clock();
  }
}

DateTime nowOf(Ref ref) => ref.watch(nowProvider);
