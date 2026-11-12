import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The screens of the app, in side bar order.
enum HomeTab { track, entries, calendar, metrics, budgets, settings }

/// The screen being shown. Screens set it to send the user somewhere else,
/// for example to Track after starting an entry.
final homeTabProvider = NotifierProvider<HomeTabNotifier, HomeTab>(
  HomeTabNotifier.new,
);

class HomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.track;

  void select(HomeTab tab) => state = tab;
}
