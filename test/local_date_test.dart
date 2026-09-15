import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/local_date.dart';

/// Proves the calendar-date type, and in particular that its gap arithmetic is
/// a function of the calendar rather than of elapsed hours.
///
/// The streak chains while the gap between two workout dates is at most three
/// days, and Friday to Monday is exactly three (`docs/01` §Progress tracking).
/// Measuring that gap by subtracting two local `DateTime`s and reading `inDays`
/// truncates, and a spring-forward day is 23 hours — so the most common
/// training pattern there is would lose its streak twice a year in every region
/// that observes daylight saving. The epoch-day tests below are what stop that.
void main() {
  group('encoding', () {
    test('a date built at 23:00 local time keeps that same local day', () {
      final lateEvening = DateTime(2026, 9, 14, 23, 0);
      expect(LocalDate.fromDateTime(lateEvening).encode(), '2026-09-14');
    });

    test('pads the year, month and day', () {
      expect(const LocalDate(2026, 1, 5).encode(), '2026-01-05');
    });

    test('round-trips through storage', () {
      const date = LocalDate(2026, 9, 14);
      expect(LocalDate.parse(date.encode()), date);
    });

    test('a stored value reads back as local midnight', () {
      final decoded = LocalDate.parse('2026-09-14').toDateTime();
      expect(decoded, DateTime(2026, 9, 14));
      expect(decoded.hour, 0);
    });
  });

  group('gap arithmetic', () {
    test('Friday to Monday is three days', () {
      const friday = LocalDate(2026, 9, 11);
      const monday = LocalDate(2026, 9, 14);
      expect(monday.daysAfter(friday), 3);
    });

    test('a spring-forward weekend is still three days', () {
      // US daylight saving began 8 March 2026; that Sunday is 23 hours long,
      // so `DateTime` subtraction would report 2 and break the chain.
      const beforeTransition = LocalDate(2026, 3, 6);
      const afterTransition = LocalDate(2026, 3, 9);
      expect(afterTransition.daysAfter(beforeTransition), 3);
    });

    test('an autumn fall-back weekend is still three days', () {
      // 25-hour Sunday on 1 November 2026: the other direction, where naive
      // subtraction can report 4 and break the chain just as wrongly.
      const beforeTransition = LocalDate(2026, 10, 30);
      const afterTransition = LocalDate(2026, 11, 2);
      expect(afterTransition.daysAfter(beforeTransition), 3);
    });

    test('crosses a month boundary', () {
      expect(
        const LocalDate(2026, 10, 2).daysAfter(const LocalDate(2026, 9, 30)),
        2,
      );
    });

    test('crosses a year boundary', () {
      expect(
        const LocalDate(2027, 1, 1).daysAfter(const LocalDate(2026, 12, 31)),
        1,
      );
    });

    test('counts 29 February in a leap year', () {
      expect(
        const LocalDate(2028, 3, 1).daysAfter(const LocalDate(2028, 2, 28)),
        2,
      );
    });

    test('skips the missing 29 February in a non-leap year', () {
      expect(
        const LocalDate(2026, 3, 1).daysAfter(const LocalDate(2026, 2, 28)),
        1,
      );
    });

    test('is negative when the other date is later', () {
      expect(
        const LocalDate(2026, 9, 11).daysAfter(const LocalDate(2026, 9, 14)),
        -3,
      );
    });

    test('addDays and daysAfter are inverses across a leap day', () {
      const start = LocalDate(2028, 2, 27);
      final shifted = start.addDays(5);
      expect(shifted, const LocalDate(2028, 3, 3));
      expect(shifted.daysAfter(start), 5);
    });
  });

  group('ordering', () {
    test('sorts chronologically across month and year boundaries', () {
      final dates = <LocalDate>[
        const LocalDate(2027, 1, 1),
        const LocalDate(2026, 9, 30),
        const LocalDate(2026, 10, 1),
        const LocalDate(2026, 12, 31),
      ]..sort();
      expect(dates.map((d) => d.encode()).toList(), <String>[
        '2026-09-30',
        '2026-10-01',
        '2026-12-31',
        '2027-01-01',
      ]);
    });

    test('compares with the relational operators', () {
      const earlier = LocalDate(2026, 9, 11);
      const later = LocalDate(2026, 9, 14);
      expect(earlier < later, isTrue);
      expect(later > earlier, isTrue);
      expect(earlier <= earlier, isTrue);
      expect(earlier >= earlier, isTrue);
      expect(later < earlier, isFalse);
    });

    test('equal dates are equal values', () {
      expect(const LocalDate(2026, 9, 14), const LocalDate(2026, 9, 14));
      expect(
        const LocalDate(2026, 9, 14).hashCode,
        const LocalDate(2026, 9, 14).hashCode,
      );
    });
  });

  group('today', () {
    test('carries no time of day', () {
      expect(todayLocal().hour, 0);
      expect(todayLocal().minute, 0);
    });

    test('matches the clock\'s calendar fields', () {
      final now = DateTime.now();
      expect(LocalDate.today(), LocalDate(now.year, now.month, now.day));
    });
  });

  group('the free helpers the bodyweight series was written against', () {
    test('still encode and decode the same values', () {
      expect(encodeCalendarDate(DateTime(2026, 9, 14, 23, 0)), '2026-09-14');
      expect(decodeCalendarDate('2026-09-14'), DateTime(2026, 9, 14));
    });
  });
}
