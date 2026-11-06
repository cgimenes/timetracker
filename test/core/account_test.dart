import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/account.dart';
import 'package:timetracker/core/validation.dart';

void main() {
  group('validateAccount', () {
    test('accepts plain and hierarchical names', () {
      for (final a in ['work', 'work:acme:dev', 'client work:x y']) {
        expect(validateAccount(a), isNull, reason: a);
      }
    });

    test('rejects invalid names', () {
      for (final a in [
        '',
        ' work',
        'work ',
        'a  b',
        'a;b',
        'a\tb',
        'a\nb',
        ':a',
        'a:',
        'a::b',
      ]) {
        expect(validateAccount(a), isNotNull, reason: '"$a"');
      }
    });
  });

  test('validateComment rejects line breaks only', () {
    expect(validateComment(null), isNull);
    expect(validateComment('fine; with ; semicolons'), isNull);
    expect(validateComment('a\nb'), isNotNull);
  });

  group('truncateAccount', () {
    test('keeps the first [level] segments', () {
      expect(truncateAccount('work:acme:dev', 1), 'work');
      expect(truncateAccount('work:acme:dev', 2), 'work:acme');
      expect(truncateAccount('work:acme:dev', 3), 'work:acme:dev');
      expect(truncateAccount('work:acme:dev', 9), 'work:acme:dev');
      expect(truncateAccount('work', 2), 'work');
    });

    test('level must be at least 1', () {
      expect(() => truncateAccount('a', 0), throwsArgumentError);
    });
  });

  group('validateEntry', () {
    final now = DateTime(2026, 10, 30, 12);
    final nine = DateTime(2026, 10, 30, 9);

    test('accepts a finished and a running entry', () {
      expect(
        validateEntry(
          account: 'a',
          start: nine,
          end: DateTime(2026, 10, 30, 10),
          now: now,
        ),
        isNull,
      );
      expect(validateEntry(account: 'a', start: nine, now: now), isNull);
    });

    test('rejects future start, future end and end not after start', () {
      expect(
        validateEntry(
          account: 'a',
          start: DateTime(2026, 10, 30, 13),
          now: now,
        ),
        'Start is in the future',
      );
      expect(
        validateEntry(
          account: 'a',
          start: nine,
          end: DateTime(2026, 10, 30, 13),
          now: now,
        ),
        'End is in the future',
      );
      expect(
        validateEntry(account: 'a', start: nine, end: nine, now: now),
        'End must be after start',
      );
    });

    test('reports account problems first', () {
      expect(
        validateEntry(account: '', start: nine, now: now),
        'Account is empty',
      );
    });
  });
}
