import 'package:flutter_test/flutter_test.dart';
import 'package:timetracker/core/timeclock.dart';

DateTime t(int h, [int m = 0, int s = 0]) => DateTime(2026, 10, 30, h, m, s);

void main() {
  group('parseLine', () {
    test('clock-in with account and comment', () {
      final line = parseLine(
        'i 2026-10-30 09:00:00 work:acme:dev  fix login',
      ) as ClockLine;
      expect(line.isIn, isTrue);
      expect(line.time, t(9));
      expect(line.account, 'work:acme:dev');
      expect(line.comment, 'fix login');
    });

    test('account with single spaces is kept whole', () {
      final line = parseLine('i 2026-10-30 09:00:00 client work') as ClockLine;
      expect(line.account, 'client work');
      expect(line.comment, isNull);
    });

    test('clock-out with and without account', () {
      final named = parseLine('o 2026-10-30 12:30:00 a:b') as ClockLine;
      expect(named.isIn, isFalse);
      expect(named.account, 'a:b');
      final bare = parseLine('o 2026-10-30 12:30:00') as ClockLine;
      expect(bare.account, isEmpty);
    });

    test('blank lines and comments are ignored, not malformed', () {
      for (final text in ['', '   ', '; note', '# note', '* note']) {
        final line = parseLine(text) as OtherLine;
        expect(line.isMalformed, isFalse, reason: text);
      }
    });

    test('malformed lines are flagged', () {
      for (final text in [
        'x 2026-10-30 09:00:00 a',
        'i 2026-10-30 09:00 a',
        'i 2026-13-30 09:00:00 a',
        'i 2026-10-30 25:00:00 a',
        'i 2026-02-30 09:00:00 a',
        'i 2026-10-30 09:00:00',
        'hello',
      ]) {
        final line = parseLine(text) as OtherLine;
        expect(line.isMalformed, isTrue, reason: text);
      }
    });

    test('tolerates a trailing carriage return and keeps it in the text', () {
      final line = parseLine('i 2026-10-30 09:00:00 a\r') as ClockLine;
      expect(line.account, 'a');
      expect(line.text, 'i 2026-10-30 09:00:00 a\r');
    });
  });

  group('format', () {
    test('canonical clock-in and clock-out', () {
      expect(
        ClockLine(isIn: true, time: t(9), account: 'a:b', comment: 'c').text,
        'i 2026-10-30 09:00:00 a:b  c',
      );
      expect(
        ClockLine(isIn: false, time: t(12, 30), account: 'a:b').text,
        'o 2026-10-30 12:30:00 a:b',
      );
    });
  });

  group('round trip', () {
    test('unchanged documents serialize byte for byte', () {
      const samples = [
        '',
        'i 2026-10-30 09:00:00 a\n',
        'i 2026-10-30 09:00:00 a', // no trailing newline
        '; header\n\ni 2026-10-30 09:00:00   a   \nbroken\n',
        'i 2026-10-30 09:00:00 a\r\no 2026-10-30 10:00:00 a\r\n',
      ];
      for (final s in samples) {
        expect(TimeclockDocument.parse(s).serialize(), s, reason: s);
      }
    });
  });

  group('entries', () {
    test('pairs clock-in and clock-out', () {
      final doc = TimeclockDocument.parse(
        'i 2026-10-30 09:00:00 a  note\no 2026-10-30 10:30:00 a\n',
      );
      expect(doc.entries, hasLength(1));
      final e = doc.entries.single;
      expect(e.account, 'a');
      expect(e.start, t(9));
      expect(e.end, t(10, 30));
      expect(e.comment, 'note');
      expect(e.isRunning, isFalse);
      expect(e.duration(t(23)), const Duration(hours: 1, minutes: 30));
      expect(doc.warnings, isEmpty);
    });

    test('concurrent sessions of different accounts', () {
      final doc = TimeclockDocument.parse(
        'i 2026-10-30 09:00:00 work:dev\n'
        'i 2026-10-30 10:00:00 work:meet\n'
        'o 2026-10-30 11:00:00 work:meet\n'
        'o 2026-10-30 12:30:00 work:dev\n',
      );
      expect(doc.entries.map((e) => (e.account, e.end)), [
        ('work:dev', t(12, 30)),
        ('work:meet', t(11)),
      ]);
    });

    test('running entry counts up to now', () {
      final doc = TimeclockDocument.parse('i 2026-10-30 09:00:00 a\n');
      final e = doc.entries.single;
      expect(e.isRunning, isTrue);
      expect(e.duration(t(9, 45)), const Duration(minutes: 45));
      expect(doc.runningEntries, hasLength(1));
    });

    test('same account twice: clock-out closes the oldest', () {
      final doc = TimeclockDocument.parse(
        'i 2026-10-30 09:00:00 a\n'
        'i 2026-10-30 10:00:00 a\n'
        'o 2026-10-30 11:00:00 a\n',
      );
      expect(doc.entries[0].end, t(11));
      expect(doc.entries[1].isRunning, isTrue);
      expect(doc.oldestRunning('a'), same(doc.entries[1]));
    });

    test('clock-out without account closes the most recent entry', () {
      final doc = TimeclockDocument.parse(
        'i 2026-10-30 09:00:00 a\n'
        'i 2026-10-30 10:00:00 b\n'
        'o 2026-10-30 11:00:00\n',
      );
      expect(doc.entries[0].isRunning, isTrue);
      expect(doc.entries[1].end, t(11));
    });

    test(
      'warns about orphan clock-outs, malformed lines and reversed times',
      () {
        final doc = TimeclockDocument.parse(
          'o 2026-10-30 08:00:00 a\n'
          'garbage\n'
          'i 2026-10-30 09:00:00 b\n'
          'o 2026-10-30 08:30:00 b\n',
        );
        expect(doc.warnings.map((w) => w.toString()), [
          'line 1: clock-out without clock-in',
          'line 2: malformed line',
          'line 4: clock-out before clock-in',
        ]);
        expect(doc.entries.single.duration(t(23)), Duration.zero);
      },
    );
  });

  group('changes', () {
    test('startEntry appends a clock-in and adds the missing newline', () {
      final doc = TimeclockDocument.parse('i 2026-10-30 08:00:00 a')
          .startEntry('b:c', t(9), comment: 'x');
      expect(
        doc.serialize(),
        'i 2026-10-30 08:00:00 a\ni 2026-10-30 09:00:00 b:c  x\n',
      );
    });

    test('startEntry rejects an invalid account', () {
      expect(
        () => TimeclockDocument.empty().startEntry('a  b', t(9)),
        throwsArgumentError,
      );
    });

    test('stopEntry appends a clock-out naming the account', () {
      final doc = TimeclockDocument.empty().startEntry('a', t(9));
      final stopped = doc.stopEntry(doc.entries.single, t(10));
      expect(
        stopped.serialize(),
        'i 2026-10-30 09:00:00 a\no 2026-10-30 10:00:00 a\n',
      );
      expect(stopped.entries.single.isRunning, isFalse);
    });

    test('stopEntry rejects finished entries and non positive durations', () {
      final doc = TimeclockDocument.empty().startEntry('a', t(9));
      expect(
        () => doc.stopEntry(doc.entries.single, t(9)),
        throwsArgumentError,
      );
      final stopped = doc.stopEntry(doc.entries.single, t(10));
      expect(
        () => stopped.stopEntry(stopped.entries.single, t(11)),
        throwsArgumentError,
      );
    });

    test('two concurrent entries stop independently', () {
      var doc = TimeclockDocument.empty()
          .startEntry('a', t(9))
          .startEntry('b', t(9, 30));
      doc = doc.stopEntry(doc.oldestRunning('a')!, t(10));
      expect(doc.runningEntries.single.account, 'b');
      doc = doc.stopEntry(doc.oldestRunning('b')!, t(11));
      expect(doc.runningEntries, isEmpty);
      expect(doc.warnings, isEmpty);
    });

    const base =
        '; keep me\n'
        'i 2026-10-30 08:00:00   a   \n'
        'o 2026-10-30 08:30:00 a\n'
        'i 2026-10-30 09:00:00 b  old\n'
        'o 2026-10-30 10:00:00 b\n'
        'broken line\n';

    test('replaceEntry rewrites only the entry lines', () {
      final doc = TimeclockDocument.parse(base);
      final edited = doc.replaceEntry(
        doc.entries[1],
        account: 'c:d',
        start: t(9, 15),
        end: t(10, 15),
        comment: 'new',
      );
      expect(
        edited.serialize(),
        '; keep me\n'
        'i 2026-10-30 08:00:00   a   \n'
        'o 2026-10-30 08:30:00 a\n'
        'i 2026-10-30 09:15:00 c:d  new\n'
        'o 2026-10-30 10:15:00 c:d\n'
        'broken line\n',
      );
    });

    test(
      'replaceEntry can finish a running entry and reopen a finished one',
      () {
        final running = TimeclockDocument.parse('i 2026-10-30 09:00:00 a\n');
        final finished = running.replaceEntry(
          running.entries.single,
          account: 'a',
          start: t(9),
          end: t(10),
        );
        expect(
          finished.serialize(),
          'i 2026-10-30 09:00:00 a\no 2026-10-30 10:00:00 a\n',
        );
        final reopened = finished.replaceEntry(
          finished.entries.single,
          account: 'a',
          start: t(9),
        );
        expect(reopened.serialize(), 'i 2026-10-30 09:00:00 a\n');
      },
    );

    test('replaceEntry validates', () {
      final doc = TimeclockDocument.parse(base);
      expect(
        () => doc.replaceEntry(doc.entries[0], account: '', start: t(9)),
        throwsArgumentError,
      );
      expect(
        () => doc.replaceEntry(
          doc.entries[0],
          account: 'a',
          start: t(9),
          end: t(9),
        ),
        throwsArgumentError,
      );
    });

    test('removeEntry drops both lines and nothing else', () {
      final doc = TimeclockDocument.parse(base);
      expect(
        doc.removeEntry(doc.entries[0]).serialize(),
        '; keep me\n'
        'i 2026-10-30 09:00:00 b  old\n'
        'o 2026-10-30 10:00:00 b\n'
        'broken line\n',
      );
    });

    test('removeEntry works for running entries', () {
      final doc = TimeclockDocument.parse(
        'i 2026-10-30 09:00:00 a\ni 2026-10-30 09:30:00 b\n',
      );
      expect(
        doc.removeEntry(doc.entries[0]).serialize(),
        'i 2026-10-30 09:30:00 b\n',
      );
    });
  });
}
