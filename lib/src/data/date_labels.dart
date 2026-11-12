/// Every date the app prints, in **one order: day, month, year**.
///
/// History used to print three formats on one journey ("Nov 10, 2026",
/// "7 Nov", "10 November 2026") and none of the short ones carried a year, so a
/// workout from last year read exactly like one from this year (audit B4, B13).
///
/// The rule (ADR 0013):
/// * **Lists** omit the year in the current year and add it otherwise
///   ("7 Nov", "7 Nov 2025").
/// * **The share card and "first logged"** always carry the year: an image
///   outlives the year it was made in, and "first logged" is a fact about
///   all time.
/// * **"Ago"** switches to years once a date is 12 months or more back.
///
/// Pure functions of calendar dates, so no clock or zone can move a label a
/// day; [today] is a parameter for the tests and defaults to the real one.
library;

import 'local_date.dart';

const List<String> _monthsShort = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _monthsLong = <String>[
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> _weekdaysShort = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

const List<String> _weekdaysLong = <String>[
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday',
];

/// "7 Nov", or "7 Nov 2025" when [date] is not in [today]'s year.
String shortDateLabel(LocalDate date, {LocalDate? today}) {
  final now = today ?? LocalDate.today();
  final base = '${date.day} ${_monthsShort[date.month - 1]}';
  return date.year == now.year ? base : '$base ${date.year}';
}

/// "Mon 28 Jul", or "Mon 28 Jul 2025" when not in [today]'s year.
String weekdayDateLabel(LocalDate date, {LocalDate? today}) =>
    '${_weekdaysShort[date.weekday - 1]} ${shortDateLabel(date, today: today)}';

/// "Mon 28 Jul 2026": **always with the year.** The share card's date, and
/// any sentence that names a workout's day for good (a delete confirmation).
String cardDateLabel(LocalDate date) =>
    '${_weekdaysShort[date.weekday - 1]} ${date.day} '
    '${_monthsShort[date.month - 1]} ${date.year}';

/// "18 Oct 2026": always with the year, for "first logged".
String dateWithYearLabel(LocalDate date) =>
    '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';

/// "Tuesday 10 November 2026", for screen readers, which should never have to
/// guess an abbreviation.
String spokenDateLabel(LocalDate date) =>
    '${_weekdaysLong[date.weekday - 1]} ${date.day} '
    '${_monthsLong[date.month - 1]} ${date.year}';

/// "September 2026".
String monthLabel(int year, int month) => '${_monthsLong[month - 1]} $year';

/// "Today", "Yesterday", then [shortDateLabel].
///
/// Relative wording only for the two days a user thinks of relatively; beyond
/// that an absolute date is what someone scanning for a session wants.
String relativeDayLabel(LocalDate date, {LocalDate? today}) {
  final now = today ?? LocalDate.today();
  final days = now.daysAfter(date);
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return shortDateLabel(date, today: now);
}

/// "today", "3 days ago", "2 weeks ago", "5 months ago", "1 year ago".
///
/// Whole calendar months, not 30-day blocks, so the 12-month switch to years
/// lands on the anniversary rather than five days early.
String agoLabel(LocalDate date, {LocalDate? today}) {
  final now = today ?? LocalDate.today();
  final days = now.daysAfter(date);
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return '1 week ago';
  if (days < 31) return '${days ~/ 7} weeks ago';

  var months = (now.year - date.year) * 12 + now.month - date.month;
  if (now.day < date.day) months -= 1;
  if (months < 1) months = 1;
  if (months < 12) return months == 1 ? '1 month ago' : '$months months ago';
  final years = months ~/ 12;
  return years == 1 ? '1 year ago' : '$years years ago';
}
