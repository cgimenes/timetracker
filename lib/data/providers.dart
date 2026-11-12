import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_util/saf_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'budget_repository.dart';
import 'saf_timeclock_storage.dart';
import 'timeclock_repository.dart';
import 'timeclock_storage.dart';

const _treeUriKey = 'treeUri';

/// Overridden in `main` with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// The stored folder if the app still has access to it. Overridden in `main`,
/// because checking the permission is asynchronous.
final initialTreeUriProvider = Provider<String?>((ref) => null);

/// Tree URI of the picked directory, null until the user picks one.
final treeUriProvider = NotifierProvider<TreeUriNotifier, String?>(
  TreeUriNotifier.new,
);

class TreeUriNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(initialTreeUriProvider);

  /// Asks the user for a directory and keeps access to it across restarts.
  /// Returns false when the user cancels.
  Future<bool> pick() async {
    final dir = await SafUtil().pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    if (dir == null) return false;
    await ref.read(sharedPreferencesProvider).setString(_treeUriKey, dir.uri);
    state = dir.uri;
    return true;
  }
}

/// The stored folder, only if access to it is still granted.
Future<String?> restoreTreeUri(SharedPreferences prefs, {SafUtil? util}) async {
  final uri = prefs.getString(_treeUriKey);
  if (uri == null) return null;
  final granted = await (util ?? SafUtil()).hasPersistedPermission(
    uri,
    checkRead: true,
    checkWrite: true,
  );
  return granted ? uri : null;
}

/// Tests override this with a fake.
final timeclockStorageProvider = Provider<TimeclockStorage>((ref) {
  final uri = ref.watch(treeUriProvider);
  if (uri == null) throw StateError('No directory picked');
  return SafTimeclockStorage(uri);
});

final timeclockRepositoryProvider = Provider<TimeclockRepository>(
  (ref) => TimeclockRepository(ref.watch(timeclockStorageProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(timeclockStorageProvider)),
);
