import 'package:flutter/material.dart';

import '../app_lifecycle.dart';
import 'home_shell.dart';
import 'theme.dart';

class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycle(
      child: MaterialApp(
        title: 'Time tracker',
        theme: appTheme(),
        darkTheme: appTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }
}
