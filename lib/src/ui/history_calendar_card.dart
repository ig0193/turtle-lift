import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/date_labels.dart';
import '../data/derived.dart' show streakLinkedDays;
import '../data/history_preview_data.dart';
import '../data/history_stats.dart';
import '../data/local_date.dart';
import '../data/training_plan.dart' show planTodayProvider;
import '../theme/app_palette.dart';
import 'history_session_row.dart';
import 'motion.dart';

/// A month calendar, swipeable between months, with a dot for every logged
/// session and the streak drawn as a run under the days it chains.
///
/// **Why a calendar at all, next to a list that already shows everything.**
/// A flat list answers "what did I do recently"; a calendar answers "did I
/// train on the 9th" and "how spread out was last month" at a glance.
///
/// **Real month arithmetic, and only as many rows as the month has weeks.**
/// The grid used to be a fixed six rows, which left an empty row under most
/// months; it now sizes to the month and animates the change (off under
/// Reduce Motion). The forward edge is bounded by the page count: `docs/01`
/// clamps `performedOn` to today or earlier, so there is no future month to
/// swipe to.
///
/// **"Today" is [planTodayProvider]**, which is refreshed on resume, so an app
/// left open across midnight into a new month can page to it (audit B15).
///
/// **The month total sits under the month name** ("6 workouts · 82 sets"),
/// for the month shown. Never the current week: that lives on the Workout
/// landing (ADR 0008).
///
/// **Streak runs.** A thin connector runs under every day between two
/// workout days that chain by the streak's own rule ([streakLinkedDays]: at
/// most three days apart), so "how does my streak work" is visible rather
/// than explained (ADR 0013).
///
/// **A day with data toggles an inline panel; an empty past day offers to log
/// a workout for it** ([onLogPastDay]); a future day does nothing.
class HistoryCalendarCard extends ConsumerStatefulWidget {
  const HistoryCalendarCard({this.onLogPastDay, super.key});

  /// Called with an empty past day the user tapped, to start a workout dated
  /// that day. Null leaves empty days inert.
  final ValueChanged<LocalDate>? onLogPastDay;

  /// Every cell's height: the 48pt tap target (turtle-taste).
  static const double cellHeight = 48;

  /// Finds one day cell, for a test to tap.
  @visibleForTesting
  static Key dayKey(DateTime day) =>
      ValueKey<String>('cal-day-${day.year}-${day.month}-${day.day}');

  /// The streak connector leaving [day] towards the next day.
  @visibleForTesting
  static Key runKey(DateTime day) =>
      ValueKey<String>('cal-run-${day.year}-${day.month}-${day.day}');

  @visibleForTesting
  static const Key prevButtonKey = ValueKey<String>('cal-prev-month');

  @visibleForTesting
  static const Key nextButtonKey = ValueKey<String>('cal-next-month');

  @visibleForTesting
  static const Key monthLabelKey = ValueKey<String>('cal-month-label');

  /// The month's grid, whose height follows its number of weeks.
  @visibleForTesting
  static const Key gridKey = ValueKey<String>('cal-grid');

  /// Jumps back to the current month once the user has paged away.
  @visibleForTesting
  static const Key thisMonthKey = ValueKey<String>('cal-this-month');

  @override
  ConsumerState<HistoryCalendarCard> createState() =>
      _HistoryCalendarCardState();
}

class _HistoryCalendarCardState extends ConsumerState<HistoryCalendarCard> {
  /// How far back swiping reaches. Ten years is comfortably more than any
  /// real install will have logged against.
  static const int _pastMonths = 120;

  late final PageController _controller;
  int _page = _pastMonths;
  DateTime? _expandedDay;
  DateTime? _lastCurrentMonth;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _monthForPage(DateTime currentMonth, int page) =>
      DateTime(currentMonth.year, currentMonth.month + page - _pastMonths);

  void _goTo(int target) {
    if (target < 0 || target > _pastMonths) return;
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
    final leading = month.weekday - 1;
    return ((leading + days) / 7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(historySessionsNewestFirstProvider);
    final figures = ref.watch(historyProjectionProvider);
    final today = ref.watch(planTodayProvider);
    final currentMonth = DateTime(today.year, today.month);
    if (_lastCurrentMonth != null && _lastCurrentMonth != currentMonth) {
      // The clock moved into a new month (resume after midnight). Page
      // indexes are relative to the current month, so an open day from the
      // old frame would point at the wrong cell.
      _expandedDay = null;
    }
    _lastCurrentMonth = currentMonth;

    final byDay = groupSessionsByDay(sessions);
    final linked = streakLinkedDays(
      <LocalDate>[for (final d in byDay.keys) LocalDate.fromDateTime(d)],
    );
    final month = _monthForPage(currentMonth, _page);
    final total = monthTotalOf(sessions, figures, month.year, month.month);
    final expandedDaySessions =
        _expandedDay == null ? null : byDay[_expandedDay];
    final weeks = _weeksIn(month);

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 16),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _NavButton(
                key: HistoryCalendarCard.prevButtonKey,
                icon: Icons.chevron_left_rounded,
                label: 'Previous month',
                enabled: _page > 0,
                onTap: () => _goTo(_page - 1),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Semantics(
                      key: HistoryCalendarCard.monthLabelKey,
                      header: true,
                      child: Text(
                        monthLabel(month.year, month.month),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.textMuted,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _NavButton(
                key: HistoryCalendarCard.nextButtonKey,
                icon: Icons.chevron_right_rounded,
                label: 'Next month',
                enabled: _page < _pastMonths,
                onTap: () => _goTo(_page + 1),
              ),
            ],
          ),
          if (_page != _pastMonths)
            Align(
              alignment: Alignment.centerRight,
              child: _Pressable(
                key: HistoryCalendarCard.thisMonthKey,
                label: 'Back to this month',
                onTap: () => _goTo(_pastMonths),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        'This month',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          // The day cells carry their own weekday for VoiceOver, so the
          // header is visual only and no longer merges into the month label.
          const ExcludeSemantics(child: _WeekdayHeader()),
          const SizedBox(height: 2),
          AnimatedContainer(
            key: HistoryCalendarCard.gridKey,
            duration: motionDuration(
                context, const Duration(milliseconds: 200)),
            curve: Curves.easeOut,
            height: HistoryCalendarCard.cellHeight * weeks,
            child: PageView.builder(
              controller: _controller,
              itemCount: _pastMonths + 1,
              onPageChanged: (page) => setState(() {
                _page = page;
                _expandedDay = null;
              }),
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
                today: today.toDateTime(),
                sessionsByDay: byDay,
                linked: linked,
                expandedDay: _expandedDay,
                onDayTap: (day) => setState(() {
                  _expandedDay = _expandedDay == day ? null : day;
                }),
                onEmptyDayTap: widget.onLogPastDay == null
                    ? null
                    : (day) =>
                        widget.onLogPastDay!(LocalDate.fromDateTime(day)),
                  ),
                ),
              ),
            ),
          ),
          if (_expandedDay != null && expandedDaySessions != null)
            _DayDetail(
              day: _expandedDay!,
              sessions: expandedDaySessions,
              figures: figures,
            ),
        ],
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
        // 48pt square: the chevrons were 32pt (audit B11).
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
    required this.sessionsByDay,
    required this.linked,
    required this.expandedDay,
    required this.onDayTap,
    required this.onEmptyDayTap,
  });

  /// The first of the month this page renders.
  final DateTime month;
  final DateTime today;
  final Map<DateTime, List<HistorySession>> sessionsByDay;
  final Set<LocalDate> linked;
  final DateTime? expandedDay;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime>? onEmptyDayTap;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is Monday=1..Sunday=7, which is already the column
    // order this grid renders (M T W T F S S).
    final leading = month.weekday - 1;
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox(),
      for (var d = 1; d <= daysInMonth; d++) _buildCell(d, todayMidnight),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var row = 0; row < cells.length ~/ 7; row++)
          SizedBox(
            height: HistoryCalendarCard.cellHeight,
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

  Widget _buildCell(int day, DateTime todayMidnight) {
    final date = DateTime(month.year, month.month, day);
    final local = LocalDate(month.year, month.month, day);
    final isFuture = date.isAfter(todayMidnight);
    final sessions = isFuture ? null : sessionsByDay[date];
    final isToday = date == todayMidnight;

    return _DayCell(
      key: HistoryCalendarCard.dayKey(date),
      date: local,
      sessionCount: sessions?.length ?? 0,
      isToday: isToday,
      isExpanded: expandedDay != null && date == expandedDay,
      isFuture: isFuture,
      linkLeft: linked.contains(local.addDays(-1)),
      linkRight: linked.contains(local),
      onTap: isFuture
          ? null
          : sessions != null
              ? () => onDayTap(date)
              : (onEmptyDayTap == null ? null : () => onEmptyDayTap!(date)),
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.date,
    required this.sessionCount,
    required this.isToday,
    required this.isExpanded,
    required this.isFuture,
    required this.linkLeft,
    required this.linkRight,
    required this.onTap,
    super.key,
  });

  final LocalDate date;
  final int sessionCount;
  final bool isToday;
  final bool isExpanded;
  final bool isFuture;

  /// Whether the streak run reaches this day from the day before.
  final bool linkLeft;

  /// Whether the streak run continues from this day to the next.
  final bool linkRight;
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
    final hasData = w.sessionCount > 0;
    final numberColor = w.isFuture
        ? AppPalette.textMuted.withValues(alpha: 0.45)
        : (w.isToday || hasData
            ? AppPalette.textPrimary
            : AppPalette.textSecondary);
    // A neutral grey, not amber: amber already marks every trained day's dot,
    // and a second amber mark per day would stop it meaning anything.
    final runColor = AppPalette.textMuted.withValues(alpha: 0.7);

    final content = Stack(
      children: <Widget>[
        if (w.linkLeft || w.linkRight)
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            height: 2,
            // Stretch: a childless ColoredBox takes its smallest constraint,
            // and a Row's loose cross axis made the line zero pixels tall.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: w.linkLeft
                      ? ColoredBox(color: runColor)
                      : const SizedBox(),
                ),
                Expanded(
                  child: w.linkRight
                      ? ColoredBox(
                          key: HistoryCalendarCard.runKey(w.date.toDateTime()),
                          color: runColor,
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        Center(
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: w.isExpanded ? AppPalette.mutedSurface : null,
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
                    fontWeight:
                        w.isToday || hasData ? FontWeight.w600 : FontWeight.w400,
                    color: numberColor,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 4,
                  child: hasData
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (var i = 0;
                                i < (w.sessionCount > 3 ? 3 : w.sessionCount);
                                i++)
                              Container(
                                width: 4,
                                height: 4,
                                margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                                decoration: const BoxDecoration(
                                  color: AppPalette.accentStrong,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // Each day its own element, named in full, so VoiceOver reads "Tuesday 10
    // November 2026, today, 2 workouts" rather than "10, 1 workout" (B10).
    final parts = <String>[
      spokenDateLabel(w.date),
      if (w.isToday) 'today',
      if (w.isFuture)
        'not yet'
      else if (hasData)
        w.sessionCount == 1 ? '1 workout' : '${w.sessionCount} workouts'
      else
        'no workout',
      if (w.isExpanded) 'open',
    ];

    return Semantics(
      container: true,
      button: w.onTap != null,
      label: parts.join(', '),
      hint: !hasData && w.onTap != null ? 'Log a workout for this day' : null,
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
          child: content,
        ),
      ),
    );
  }
}

/// The session (or sessions) on the day currently expanded, each a full
/// [HistorySessionRow] -- tapping one opens it, exactly as it would from the
/// Recent list.
class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.sessions,
    required this.figures,
  });

  final DateTime day;
  final List<HistorySession> sessions;
  final Map<String, HistoryRowFigures> figures;

  @override
  Widget build(BuildContext context) {
    // The app's one date order (day month, year only when not this year) and
    // its one word for an entry (audit B13).
    final label = weekdayDateLabel(LocalDate.fromDateTime(day)) +
        (sessions.length > 1 ? ' · ${sessions.length} workouts' : '');

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppPalette.textMuted,
              ),
            ),
          ),
          for (final session in sessions)
            HistorySessionRow(session: session, figures: figures[session.id]!),
        ],
      ),
    );
  }
}
