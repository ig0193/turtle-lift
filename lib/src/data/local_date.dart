import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;

/// A local calendar date: a year, a month and a day, with no time and no zone.
///
/// **This is not a timestamp, and that is the whole point.** `CLAUDE.md` is
/// explicit that `performedOn` is a calendar date — an 11pm session must file
/// on the day the user experienced, not on the next UTC day. A `DateTime`
/// carries an instant and a zone, so every function that takes one is a place
/// where a day can shift by one.
///
/// **Arithmetic runs on the date triple, never on two `DateTime`s.** Subtracting
/// local `DateTime`s and reading `inDays` truncates, and a spring-forward day is
/// 23 hours — so a three-day gap measures as two. The streak chains while the
/// gap is at most three days precisely because Friday to Monday is three
/// (`docs/01` §Progress tracking), so that truncation lands on the most common
/// training pattern there is, in every region that observes daylight saving,
/// twice a year. [epochDay] converts through the civil calendar instead, where
/// a day is a day.
///
/// Stored as `YYYY-MM-DD` text through [LocalDateConverter]. Text in ISO order
/// sorts and compares correctly as a string, which is all the database needs.
@immutable
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  /// The local calendar date it is right now.
  ///
  /// The one place the clock is read, so "dated today" is a single fact rather
  /// than a `DateTime.now()` in every caller, each of which is a chance to keep
  /// the time of day.
  factory LocalDate.today() {
    final now = DateTime.now();
    return LocalDate(now.year, now.month, now.day);
  }

  /// The calendar date a `DateTime` falls on, in whatever zone it carries.
  factory LocalDate.fromDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  /// Reads a stored `YYYY-MM-DD`.
  ///
  /// `DateTime.parse` reads a date-only string as local midnight, which is what
  /// is wanted; going through the fields makes that a stated intention rather
  /// than a behaviour someone has to look up.
  factory LocalDate.parse(String stored) {
    final parsed = DateTime.parse(stored);
    return LocalDate(parsed.year, parsed.month, parsed.day);
  }

  final int year;
  final int month;
  final int day;

  /// `YYYY-MM-DD`.
  ///
  /// **Hand-formatted rather than `toIso8601String().substring(0, 10)`.** That
  /// shortcut reads the fields of whatever zone the value is in, so a UTC
  /// instant that slipped through would silently produce the wrong day for half
  /// of every evening. Formatting the fields explicitly makes the result a
  /// function of the calendar and nothing else.
  String encode() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Local midnight on this date, for the few APIs that insist on a `DateTime`.
  DateTime toDateTime() => DateTime(year, month, day);

  /// Days since 1970-01-01, computed from the civil calendar.
  ///
  /// This is what makes gap arithmetic exact. It is Howard Hinnant's
  /// `days_from_civil`, which is the standard branch-free form and is correct
  /// for every proleptic Gregorian date, leap years included.
  int get epochDay {
    final shiftedYear = year - (month <= 2 ? 1 : 0);
    final era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) ~/ 400;
    final yearOfEra = shiftedYear - era * 400;
    final dayOfYear =
        (153 * (month + (month > 2 ? -3 : 9)) + 2) ~/ 5 + day - 1;
    final dayOfEra =
        yearOfEra * 365 + yearOfEra ~/ 4 - yearOfEra ~/ 100 + dayOfYear;
    return era * 146097 + dayOfEra - 719468;
  }

  /// How many days later this date is than [other]. Negative when earlier.
  int daysAfter(LocalDate other) => epochDay - other.epochDay;

  /// This date shifted by [days], forwards or backwards.
  LocalDate addDays(int days) {
    final shifted = DateTime(year, month, day + days);
    return LocalDate(shifted.year, shifted.month, shifted.day);
  }

  /// Strictly before [other]. Reads as prose where one workout is being
  /// compared to another.
  bool isBefore(LocalDate other) => compareTo(other) < 0;

  /// Strictly after [other].
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  @override
  int compareTo(LocalDate other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => encode();
}

/// Stores a [LocalDate] as `YYYY-MM-DD` text.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.encode();
}

/// `YYYY-MM-DD` for a `DateTime`, keeping its calendar fields.
///
/// Kept as a free function because the bodyweight series and the Profile screen
/// were written against it. New code should prefer [LocalDate].
String encodeCalendarDate(DateTime date) =>
    LocalDate.fromDateTime(date).encode();

/// The local calendar date a stored `YYYY-MM-DD` names, as a `DateTime`.
DateTime decodeCalendarDate(String stored) => LocalDate.parse(stored).toDateTime();

/// Today, as a `DateTime` at local midnight.
DateTime todayLocal() => LocalDate.today().toDateTime();
