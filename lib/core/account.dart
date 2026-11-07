/// Returns an error message, or null when [account] is valid.
///
/// hledger separates the account from the comment with two spaces, so an
/// account cannot contain them. Segments are separated by `:`.
String? validateAccount(String account) {
  if (account.isEmpty) return 'Account is empty';
  if (account != account.trim()) {
    return 'Account has leading or trailing spaces';
  }
  if (account.contains('  ')) return 'Account has two consecutive spaces';
  if (account.contains(RegExp(r'[;\t\r\n]'))) {
    return 'Account has an invalid character';
  }
  if (account.split(':').any((s) => s.isEmpty)) {
    return 'Account has an empty segment';
  }
  return null;
}

/// Returns an error message, or null when [comment] is valid.
String? validateComment(String? comment) {
  if (comment == null) return null;
  if (comment.contains(RegExp(r'[\r\n]'))) return 'Comment has a line break';
  return null;
}

/// Account depth: level 1 of `work:acme:dev` is `work`, level 2 is `work:acme`.
String truncateAccount(String account, int level) {
  if (level < 1) throw ArgumentError.value(level, 'level', 'must be >= 1');
  final parts = account.split(':');
  return parts.length <= level ? account : parts.take(level).join(':');
}

/// Number of segments in [account].
int accountDepth(String account) => account.split(':').length;

/// First level of the account: `work` in `work:acme:dev`.
String projectOf(String account) => truncateAccount(account, 1);
