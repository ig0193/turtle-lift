import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
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
        button: true,
        label: 'Workout date, ${isToday ? 'today' : longDateLabel(date)}',
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
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isToday ? AppPalette.surface : AppPalette.mutedSurface,
                border: Border.all(
                  color: isToday ? AppPalette.border : AppPalette.accentStrong,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                isToday ? 'Today' : longDateLabel(date),
                style: TextStyle(
                  fontSize: 12.5,
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
    final today = LocalDate.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.toDateTime(),
      firstDate: today.addDays(-365 * 5).toDateTime(),
      // The picker cannot offer tomorrow at all, so the clamp is a second line
      // of defence rather than the only one.
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
    if (picked == null) return;
    await ref
        .read(activeSessionProvider.notifier)
        .setPerformedOn(LocalDate.fromDateTime(picked));
  }
}

/// `Mon 28 Jul` — enough to recognise the day at a glance without a year that
/// is almost always this one.
String longDateLabel(LocalDate date) {
  const days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final weekday = days[date.toDateTime().weekday - 1];
  return '$weekday ${date.day} ${months[date.month - 1]}';
}
