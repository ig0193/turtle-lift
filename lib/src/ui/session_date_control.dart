import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/date_labels.dart';
import '../data/local_date.dart';
import '../theme/app_palette.dart';

/// The day this workout will be saved under.
///
/// **Prominent whenever it is not today.** Retrospective logging is a
/// first-class path — a Monday session logged on Tuesday must file as Monday or
/// it breaks the streak with no way to fix it — and the risk that creates is
/// backdating by accident and not noticing. So today is a quiet chip and any
/// other day is spelled out.
///
/// **Clamped to today or earlier.** A future-dated workout would make the
/// streak meaningless. The clamp validates the date the user picks; it never
/// rewrites one already stored.
class SessionDateControl extends ConsumerWidget {
  const SessionDateControl({super.key});

  /// The key a test taps to open the picker.
  static const Key chipKey = ValueKey<String>('session-date');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();

    final date = session.performedOn;
    final isToday = date == LocalDate.today();

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        container: true,
        button: true,
        label: 'Workout date, ${isToday ? 'today' : longDateLabel(date)}',
        onTap: () => _pick(context, ref, date),
        excludeSemantics: true,
        child: GestureDetector(
          key: chipKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => _pick(context, ref, date),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isToday ? AppPalette.surface : AppPalette.mutedSurface,
                border: Border.all(
                  color: isToday ? AppPalette.border : AppPalette.accentStrong,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isToday ? 'Today' : longDateLabel(date),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w400 : FontWeight.w600,
                  color: isToday
                      ? AppPalette.textSecondary
                      : AppPalette.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    LocalDate current,
  ) async {
    final picked = await ref.read(workoutDatePickerProvider)(context, current);
    if (picked == null) return;
    await ref.read(activeSessionProvider.notifier).setPerformedOn(picked);
  }
}

/// Asks for the day a workout happened, starting at [current]; null when the
/// user backs out.
typedef WorkoutDatePicker = Future<LocalDate?> Function(
  BuildContext context,
  LocalDate current,
);

/// The date picker the live workout and a saved one both use. A provider so a
/// test can answer it without driving Material's calendar.
final workoutDatePickerProvider =
    Provider<WorkoutDatePicker>((ref) => showWorkoutDatePicker);

/// The one picker for a workout's day: five years back, **never past today**.
///
/// A future-dated workout would make the streak meaningless, so the picker
/// cannot offer tomorrow at all; the store's clamp is a second line of
/// defence rather than the only one.
Future<LocalDate?> showWorkoutDatePicker(
  BuildContext context,
  LocalDate current,
) async {
  final today = LocalDate.today();
  final picked = await showDatePicker(
    context: context,
    initialDate: (current.isAfter(today) ? today : current).toDateTime(),
    firstDate: today.addDays(-365 * 5).toDateTime(),
    lastDate: today.toDateTime(),
    // Painted from the app's own surfaces: `app_theme.dart` sets no
    // date-picker theme, and Material's defaults bring a palette this app
    // uses nowhere.
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppPalette.surface,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: AppPalette.mutedSurface,
          headerForegroundColor: AppPalette.textPrimary,
          dayForegroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppPalette.onAccent
                : AppPalette.textPrimary,
          ),
          dayBackgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppPalette.accentStrong
                : Colors.transparent,
          ),
          todayForegroundColor:
              WidgetStateProperty.all(AppPalette.accentStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.border),
          ),
        ),
      ),
      child: child!,
    ),
  );
  if (picked == null) return null;
  return LocalDate.fromDateTime(picked);
}

/// `Mon 28 Jul`, or `Mon 28 Jul 2025` once it is not this year: the picker
/// reaches five years back, and a backdated workout from last year must not
/// read like one from this year (audit B4).
String longDateLabel(LocalDate date) => weekdayDateLabel(date);
