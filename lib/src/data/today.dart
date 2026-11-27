import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_date.dart';

/// How many weekdays there are. Weekdays are 0 = Monday ... 6 = Sunday, and
/// the week starts on Monday.
const int kWeekdayCount = 7;

/// Monday of the week containing [date].
LocalDate startOfWeek(LocalDate date) => date.addDays(1 - date.weekday);

/// Where "today" comes from. The device clock, unless a test swaps it to
/// walk a fake clock across midnight.
final planClockProvider = Provider<LocalDate Function()>(
  (ref) => LocalDate.today,
);

/// Today, read from [planClockProvider]. A provider so a test can pin it.
///
/// **Refreshed on resume** (KTD13). The value is cached until something
/// invalidates it, so an app left open across midnight would otherwise keep
/// showing yesterday as today. `RefreshTodayOnResume` in `main.dart`
/// invalidates it whenever the app comes back to the foreground, and every
/// provider that watches it -- History's calendar, every Diet figure --
/// recomputes from the new date. An invalidation that finds the same date
/// changes nothing downstream, because [LocalDate] compares by value.
///
/// Stores never read this for "today": a write can happen in the moment
/// before a resume refresh, so `DietLogStore` reads its own clock at write
/// time.
final planTodayProvider =
    Provider<LocalDate>((ref) => ref.watch(planClockProvider)());
