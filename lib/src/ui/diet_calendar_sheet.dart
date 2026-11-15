import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/date_labels.dart';
import '../data/diet_derived.dart' show dietLoggedDatesProvider;
import '../data/local_date.dart';
import '../data/today.dart' show planTodayProvider;
import '../theme/app_palette.dart';
import 'diet_pane.dart' show dietSelectedDayProvider, showDietDay;
import 'motion.dart';

/// The Diet header's date picker button
/// (`docs/adr/0017-diet-date-picker.md`).
///
/// A calendar glyph in the pinned header, where the Diet tab's own actions go
/// (`L0TabSpec.actions`). It opens [showDietCalendarSheet]. Header actions are
/// per tab, so this shows on Diet and nowhere else.
class DietCalendarButton extends ConsumerWidget {
  const DietCalendarButton({super.key});

  @visibleForTesting
  static const Key buttonKey = ValueKey<String>('diet-calendar-button');

  static const String label = 'Pick a date';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() => showDietCalendarSheet(context);
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        key: buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.calendar_month_outlined,
            size: 22,
            color: AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Opens the calendar over the Diet tab. Picking a day selects it and closes
/// the sheet; the week strip then shows that day's week.
Future<void> showDietCalendarSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const DietCalendarSheet(),
    );

/// A month calendar, swipeable between months, with a dot on every day that
/// has food logged, in the look of the Activity calendar.
///
/// **Only today and earlier can be picked.** Diet is a log
/// (`docs/adr/0015-diet-is-a-log.md`); a day that has not happened has nothing
/// to log, so its cell is inert and dimmed, and there is no month after the
/// current one to swipe to.
///
/// **It opens on the month of the selected day**, so a user who picked
/// something three months back finds it where they left it. The selected day
/// carries a filled disc, today a ring, a logged day a dot: three different
/// marks, so none depends on colour alone.
///
/// "Today" is [planTodayProvider], refreshed on resume, so an app left open
/// across midnight can page to the new day.
class DietCalendarSheet extends ConsumerStatefulWidget {
  const DietCalendarSheet({super.key});

  /// Every cell's height: the 48pt tap target (turtle-taste).
  static const double cellHeight = 48;

  /// How far back swiping reaches, in months. Ten years, as Activity's.
  static const int pastMonths = 120;

  static Key dayKey(LocalDate day) =>
      ValueKey<String>('diet-cal-day-${day.year}-${day.month}-${day.day}');

  @visibleForTesting
  static const Key prevButtonKey = ValueKey<String>('diet-cal-prev');

  @visibleForTesting
  static const Key nextButtonKey = ValueKey<String>('diet-cal-next');

  @visibleForTesting
  static const Key monthLabelKey = ValueKey<String>('diet-cal-month');

  @visibleForTesting
  static const Key gridKey = ValueKey<String>('diet-cal-grid');

  /// Jumps to today: selects it, closes the sheet.
  @visibleForTesting
  static const Key todayKey = ValueKey<String>('diet-cal-today');

  /// The dot under a day that has food logged.
  @visibleForTesting
  static Key markerKey(LocalDate day) =>
      ValueKey<String>('diet-cal-dot-${day.year}-${day.month}-${day.day}');

  @override
  ConsumerState<DietCalendarSheet> createState() => _DietCalendarSheetState();
}

class _DietCalendarSheetState extends ConsumerState<DietCalendarSheet> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    final today = ref.read(planTodayProvider);
    final selected = ref.read(dietSelectedDayProvider);
    // Page indexes count months back from the current one, so the last page is
    // this month. A selection older than the swipe range opens on the oldest
    // month rather than off the end.
    final monthsBack =
        (today.year - selected.year) * 12 + today.month - selected.month;
    _page = (DietCalendarSheet.pastMonths - monthsBack)
        .clamp(0, DietCalendarSheet.pastMonths);
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _monthForPage(DateTime currentMonth, int page) => DateTime(
      currentMonth.year,
      currentMonth.month + page - DietCalendarSheet.pastMonths);

  void _goTo(int target) {
    if (target < 0 || target > DietCalendarSheet.pastMonths) return;
    if (prefersReducedMotion(context)) {
      _controller.jumpToPage(target);
      return;
    }
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  static int _weeksIn(DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    return ((month.weekday - 1 + days) / 7).ceil();
  }

  void _pick(LocalDate day) {
    showDietDay(ref, day);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(planTodayProvider);
    final selected = ref.watch(dietSelectedDayProvider);
    final logged = ref.watch(dietLoggedDatesProvider);
    final currentMonth = DateTime(today.year, today.month);
    final month = _monthForPage(currentMonth, _page);
    final weeks = _weeksIn(month);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                _NavButton(
                  key: DietCalendarSheet.prevButtonKey,
                  icon: Icons.chevron_left_rounded,
                  label: 'Previous month',
                  enabled: _page > 0,
                  onTap: () => _goTo(_page - 1),
                ),
                Expanded(
                  child: Semantics(
                    key: DietCalendarSheet.monthLabelKey,
                    header: true,
                    child: Text(
                      monthLabel(month.year, month.month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ),
                ),
                _NavButton(
                  key: DietCalendarSheet.nextButtonKey,
                  icon: Icons.chevron_right_rounded,
                  label: 'Next month',
                  enabled: _page < DietCalendarSheet.pastMonths,
                  onTap: () => _goTo(_page + 1),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const ExcludeSemantics(child: _WeekdayHeader()),
            const SizedBox(height: 2),
            AnimatedContainer(
              key: DietCalendarSheet.gridKey,
              duration:
                  motionDuration(context, const Duration(milliseconds: 200)),
              curve: Curves.easeOut,
              height: DietCalendarSheet.cellHeight * weeks,
              child: PageView.builder(
                controller: _controller,
                itemCount: DietCalendarSheet.pastMonths + 1,
                onPageChanged: (page) => setState(() => _page = page),
                // A neighbouring month can have one more week than the grid's
                // current height while it slides in; it is clipped at the
                // bottom rather than overflowing, and the height follows once
                // the page settles.
                itemBuilder: (context, page) => ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: _MonthGrid(
                      month: _monthForPage(currentMonth, page),
                      today: today,
                      selected: selected,
                      logged: logged,
                      onPick: _pick,
                    ),
                  ),
                ),
              ),
            ),
            _Pressable(
              key: DietCalendarSheet.todayKey,
              label: 'Go to today',
              onTap: () => _pick(today),
              child: const SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims while pressed: the feedback a `GestureDetector` does not give.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        enabled: widget.onTap != null,
        label: widget.label,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          child: AnimatedOpacity(
            opacity: _down ? 0.55 : 1,
            duration: const Duration(milliseconds: 80),
            child: widget.child,
          ),
        ),
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Pressable(
        label: label,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? AppPalette.textSecondary
                : AppPalette.textMuted.withValues(alpha: 0.4),
          ),
        ),
      );
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const _labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          for (final label in _labels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.textMuted,
                  ),
                ),
              ),
            ),
        ],
      );
}

/// One month's grid of day cells, as many rows as the month has weeks.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.logged,
    required this.onPick,
  });

  /// The first of the month this page renders.
  final DateTime month;
  final LocalDate today;
  final LocalDate selected;
  final Set<LocalDate> logged;
  final ValueChanged<LocalDate> onPick;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is Monday=1..Sunday=7, already the column order here.
    final leading = month.weekday - 1;

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox(),
      for (var d = 1; d <= daysInMonth; d++)
        _buildCell(LocalDate(month.year, month.month, d)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var row = 0; row < cells.length ~/ 7; row++)
          SizedBox(
            height: DietCalendarSheet.cellHeight,
            child: Row(
              children: <Widget>[
                for (final cell in cells.sublist(row * 7, row * 7 + 7))
                  Expanded(child: cell),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(LocalDate date) {
    final isFuture = date > today;
    return _DayCell(
      key: DietCalendarSheet.dayKey(date),
      date: date,
      isToday: date == today,
      isSelected: date == selected,
      isFuture: isFuture,
      hasLog: !isFuture && logged.contains(date),
      onTap: isFuture ? null : () => onPick(date),
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.hasLog,
    required this.onTap,
    super.key,
  });

  final LocalDate date;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final bool hasLog;
  final VoidCallback? onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _down = false;

  void _press(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final numberColor = w.isFuture
        ? AppPalette.textMuted.withValues(alpha: 0.45)
        : (w.isToday || w.isSelected || w.hasLog
            ? AppPalette.textPrimary
            : AppPalette.textSecondary);

    // Each day its own element, named in full, so a screen reader hears
    // "Tuesday 10 November 2026, today, food logged" and not "10".
    final parts = <String>[
      spokenDateLabel(w.date),
      if (w.isToday) 'today',
      if (w.isFuture)
        'not yet'
      else if (w.hasLog)
        'food logged'
      else
        'nothing logged',
      if (w.isSelected) 'selected',
    ];

    return Semantics(
      container: true,
      button: w.onTap != null,
      selected: w.isSelected,
      label: parts.join(', '),
      onTap: w.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: w.onTap,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedOpacity(
          opacity: _down ? 0.55 : 1,
          duration: const Duration(milliseconds: 80),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: w.isSelected ? AppPalette.mutedSurface : null,
                border: w.isToday
                    ? Border.all(color: AppPalette.textSecondary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${w.date.day}',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: w.isToday || w.isSelected || w.hasLog
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: numberColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 4,
                    child: w.hasLog
                        ? Container(
                            key: DietCalendarSheet.markerKey(w.date),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppPalette.accentStrong,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
