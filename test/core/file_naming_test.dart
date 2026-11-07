import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/account.dart';
import 'package:timetracker/core/file_naming.dart';

String name(DateTime d, SplitMethod s, [String? template]) =>
    fileNameFor(d, s, template ?? defaultFileNameTemplate(s));

void main() {
  group('fileNameFor', () {
    final d = DateTime(2026, 3, 5, 14);

    test('default templates', () {
      expect(name(d, SplitMethod.none), 'time.timeclock');
      expect(name(d, SplitMethod.day), '2026-03-05.timeclock');
      expect(name(d, SplitMethod.week), '2026-W10.timeclock');
      expect(name(d, SplitMethod.month), '2026-03.timeclock');
    });

    test('custom template', () {
      expect(
        name(d, SplitMethod.month, 'hours-{MM}-{yyyy}.timeclock'),
        'hours-03-2026.timeclock',
      );
    });

    test('ISO week year differs from the calendar year at year boundaries', () {
      // 2026-01-01 is a Thursday: week 1 of 2026.
      expect(
        name(DateTime(2026, 1, 1), SplitMethod.week),
        '2026-W01.timeclock',
      );
      // 2027-01-01 is a Friday: still week 53 of 2026.
      expect(
        name(DateTime(2027, 1, 1), SplitMethod.week),
        '2026-W53.timeclock',
      );
      // 2024-12-30 is a Monday: week 1 of 2025.
      expect(
        name(DateTime(2024, 12, 30), SplitMethod.week),
        '2025-W01.timeclock',
      );
      // Sunday 2026-10-25 closes the week that began on Monday the 19th.
      expect(
        name(DateTime(2026, 10, 25), SplitMethod.week),
        '2026-W43.timeclock',
      );
      expect(
        name(DateTime(2026, 10, 26), SplitMethod.week),
        '2026-W44.timeclock',
      );
    });

    test('calendar year is used when the template has no week', () {
      expect(
        name(DateTime(2027, 1, 1), SplitMethod.month),
        '2027-01.timeclock',
      );
    });

    test('days are unaffected by DST changes', () {
      expect(
        name(DateTime(2026, 3, 29), SplitMethod.week),
        '2026-W13.timeclock',
      );
      expect(
        name(DateTime(2026, 10, 25), SplitMethod.day),
        '2026-10-25.timeclock',
      );
    });
  });

  group('validateFileNameTemplate', () {
    test('defaults are valid for their own split', () {
      for (final s in SplitMethod.values) {
        expect(validateFileNameTemplate(defaultFileNameTemplate(s), s), isNull);
      }
    });

    test('must keep every period apart', () {
      expect(
        validateFileNameTemplate('{yyyy}.timeclock', SplitMethod.month),
        isNotNull,
      );
      expect(
        validateFileNameTemplate('{yyyy}-{MM}.timeclock', SplitMethod.day),
        isNotNull,
      );
      expect(
        validateFileNameTemplate('{MM}-{ww}.timeclock', SplitMethod.week),
        isNotNull,
      );
      expect(
        validateFileNameTemplate('anything.timeclock', SplitMethod.none),
        isNull,
      );
    });

    test('rejects empty names, paths and other extensions', () {
      expect(validateFileNameTemplate('', SplitMethod.none), isNotNull);
      expect(
        validateFileNameTemplate('a/b.timeclock', SplitMethod.none),
        isNotNull,
      );
      expect(
        validateFileNameTemplate(r'a\b.timeclock', SplitMethod.none),
        isNotNull,
      );
      expect(validateFileNameTemplate('time.txt', SplitMethod.none), isNotNull);
    });
  });

  test('isTimeclockFile', () {
    expect(isTimeclockFile('2026-03.timeclock'), isTrue);
    expect(isTimeclockFile('2026-03.timeclock.txt'), isFalse);
  });

  group('split by project', () {
    final d = DateTime(2026, 3, 5, 14);

    test('default templates put the project first', () {
      String t(SplitMethod m) => defaultFileNameTemplate(m, byProject: true);
      expect(t(SplitMethod.none), '{project}.timeclock');
      expect(t(SplitMethod.day), '{project}-{yyyy}-{MM}-{dd}.timeclock');
      expect(t(SplitMethod.week), '{project}-{yyyy}-W{ww}.timeclock');
      expect(t(SplitMethod.month), '{project}-{yyyy}-{MM}.timeclock');
    });

    test('defaults are valid for their own choice', () {
      for (final s in SplitMethod.values) {
        expect(
          validateFileNameTemplate(
            defaultFileNameTemplate(s, byProject: true),
            s,
            byProject: true,
          ),
          isNull,
        );
      }
    });

    test('the project token is required when on and refused when off', () {
      expect(
        validateFileNameTemplate(
          '{yyyy}-{MM}.timeclock',
          SplitMethod.month,
          byProject: true,
        ),
        contains('{project}'),
      );
      expect(
        validateFileNameTemplate(
          '{project}-{yyyy}-{MM}.timeclock',
          SplitMethod.month,
        ),
        contains('Split by project'),
      );
    });

    test('the period tokens are still required', () {
      expect(
        validateFileNameTemplate(
          '{project}.timeclock',
          SplitMethod.month,
          byProject: true,
        ),
        contains('{yyyy}'),
      );
    });

    test('fileNameFor puts the project in the name', () {
      expect(
        fileNameFor(
          d,
          SplitMethod.month,
          '{project}-{yyyy}-{MM}.timeclock',
          project: 'work',
        ),
        'work-2026-03.timeclock',
      );
      expect(
        fileNameFor(
          d,
          SplitMethod.none,
          '{project}.timeclock',
          project: 'personal',
        ),
        'personal.timeclock',
      );
    });

    test('unsafe characters in the project become underscores', () {
      String name(String project) => fileNameFor(
        d,
        SplitMethod.none,
        '{project}.timeclock',
        project: project,
      );
      expect(name('a/b'), 'a_b.timeclock');
      expect(name(r'a\b:c*d?'), 'a_b_c_d_.timeclock');
      expect(name('client work'), 'client work.timeclock'); // spaces are fine
      expect(name('.hidden'), '_hidden.timeclock');
      expect(name('..'), '_.timeclock');
    });

    test('the project of an account is its first level', () {
      expect(projectOf('work:acme:dev'), 'work');
      expect(projectOf('personal'), 'personal');
    });
  });
}
