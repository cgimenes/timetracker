import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/providers.dart';
import 'notifications/running_notifier.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final treeUri = await restoreTreeUri(prefs);
  await initRunningNotifications();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialTreeUriProvider.overrideWithValue(treeUri),
      ],
      child: const TimeTrackerApp(),
    ),
  );
}
