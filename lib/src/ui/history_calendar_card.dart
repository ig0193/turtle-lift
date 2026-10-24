import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_preview_data.dart';
import '../theme/app_palette.dart';
import 'history_session_row.dart';

/// A month calendar, swipeable between months, with a dot on every day that
/// has a logged session.
///
/// **Why a calendar at all, next to a list that already shows everything.**
/// A flat list answers "what did I do recently"; a calendar answers "did I
/// train on the 9th" and "how spread out was last month" at a glance, in a
/// shape nobody has to read line by line. The two are complementary, which is
/// why this sits above the Recent list on [HistoryRoot] rather than replacing
/// it.
///
/// **Real month arithmetic, not a static 30-day grid.** [PageView.builder]
/// pages through actual calendar months via plain [DateTime] maths, so every
/// month's weekday columns line up correctly and leap years need no special
/// case. The forward edge is bounded by [itemCount] rather than by disabling
/// the "next" button alone -- `docs/01-app-idea.md` clamps `performedOn` to
/// today or earlier, and a calendar that could swipe into next month would
/// let a user go looking for a session that can never exist there.
///
/// **A day with data toggles an inline detail panel; it never navigates on
/// its own.** A day showing only a dot carries no title, so jumping straight
/// to a session from a bare dot is a blind tap. Revealing which workout (or
/// workouts) happened that day first, via the same [HistorySessionRow] the
/// Recent list already uses, means the user always taps into something they
/// have already read -- one rule for a day with one session and a day with
/// three, rather than two different behaviours to learn.
class HistoryCalendarCard extends ConsumerStatefulWidget {
  const HistoryCalendarCard({super.key});

  /// Finds one day cell, for a test to tap.
  @visibleForTesting
  static Key dayKey(DateTime day) =>
      ValueKey<String>('cal-day-${day.year}-${day.month}-${day.day}');

  @visibleForTesting
  static const Key prevButtonKey = ValueKey<String>('cal-prev-month');

  @visibleForTesting
  static const Key nextButtonKey = ValueKey<String>('cal-next-month');

  @visibleForTesting
  static const Key monthLabelKey = ValueKey<String>('cal-month-label');

  @override
  ConsumerState<HistoryCalendarCard> createState() =>
      _HistoryCalendarCardState();
}

class _HistoryCalendarCardState extends ConsumerState<HistoryCalendarCard> {
  /// How far back swiping reaches. Ten years is comfortably more than any
  /// real install will have logged against, and a fixed span is what lets the
  /// forward edge be enforced structurally (see the class doc) rather than by
  /// a button alone.
  static const int _pastMonths = 120;

  static const double _cellHeight = 38;

  /// Every month fits in 6 rows of 7 (worst case: a 31-day month starting on
  /// the last weekday slot is 6 + 31 = 37 cells, which still fits 42). Fixing
  /// it at 6 means every page is the same height, which a [PageView] inside a
  /// scrolling list needs -- a page that grew or shrank with the month shown
  /// would have nothing to tell the list around it to re-measure.
  static const int _weekRows = 6;

  late final DateTime _currentMonthStart;
  late final PageController _controller;
  late int _page;
  DateTime? _expandedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonthStart = DateTime(now.year, now.month);
    _page = _pastMonths;
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) {
    final offset = page - _pastMonths;
    return DateTime(_currentMonthStart.year, _currentMonthStart.month + offset);
  }

  void _step(int delta) {
    final target = _page + delta;
    if (target < 0 || target > _pastMonths) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(historySessionsNewestFirstProvider);
    final figures = ref.watch(historyProjectionProvider);
    final byDay = groupSessionsByDay(sessions);
    final today = DateTime.now();
    final month = _monthForPage(_page);
    final expandedDaySessions =
        _expandedDay == null ? null : byDay[_expandedDay];

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _NavButton(
                key: HistoryCalendarCard.prevButtonKey,
                icon: Icons.chevron_left_rounded,
                label: 'Previous month',
                enabled: _page > 0,
                onTap: () => _step(-1),
              ),
              Semantics(
                key: HistoryCalendarCard.monthLabelKey,
                header: true,
                child: Text(
                  monthYearLabel(month),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
              _NavButton(
                key: HistoryCalendarCard.nextButtonKey,
                icon: Icons.chevron_right_rounded,
                label: 'Next month',
                enabled: _page < _pastMonths,
                onTap: () => _step(1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _WeekdayHeader(),
          const SizedBox(height: 2),
          SizedBox(
            height: _cellHeight * _weekRows,
            child: PageView.builder(
              controller: _controller,
              itemCount: _pastMonths + 1,
              onPageChanged: (page) => setState(() {
                _page = page;
                _expandedDay = null;
              }),
              itemBuilder: (context, page) => _MonthGrid(
                month: _monthForPage(page),
                today: today,
                sessionsByDay: byDay,
                expandedDay: _expandedDay,
                cellHeight: _cellHeight,
                onDayTap: (day) => setState(() {
                  _expandedDay = _expandedDay == day ? null : day;
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '‹ Swipe to change month ›',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: AppPalette.textMuted),
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? AppPalette.textSecondary
                  : AppPalette.textMuted.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const _labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Days of the week, Monday through Sunday',
        excludeSemantics: true,
        child: Row(
          children: <Widget>[
            for (final label in _labels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppPalette.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// One month's fixed 6×7 grid of day cells.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.sessionsByDay,
    required this.expandedDay,
    required this.cellHeight,
    required this.onDayTap,
  });

  /// The first of the month this page renders.
  final DateTime month;
  final DateTime today;
  final Map<DateTime, List<HistorySession>> sessionsByDay;
  final DateTime? expandedDay;
  final double cellHeight;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is Monday=1..Sunday=7, which is already the column
    // order this grid renders (M T W T F S S) -- no remapping needed.
    final leading = month.weekday - 1;
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox(),
      for (var d = 1; d <= daysInMonth; d++) _buildCell(d, todayMidnight),
    ];
    // Pad to a full 42 cells so every month's page is the same height,
    // whether it needed 4 rows or 6.
    while (cells.length < 42) {
      cells.add(const SizedBox());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var row = 0; row < 6; row++)
          SizedBox(
            height: cellHeight,
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
    final isFuture = date.isAfter(todayMidnight);
    final sessions = isFuture ? null : sessionsByDay[date];
    final isToday = date == todayMidnight;
    final isExpanded = expandedDay != null && date == expandedDay;

    return _DayCell(
      key: HistoryCalendarCard.dayKey(date),
      day: day,
      sessionCount: sessions?.length ?? 0,
      isToday: isToday,
      isExpanded: isExpanded,
      isFuture: isFuture,
      onTap: sessions == null ? null : () => onDayTap(date),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.sessionCount,
    required this.isToday,
    required this.isExpanded,
    required this.isFuture,
    required this.onTap,
    super.key,
  });

  final int day;
  final int sessionCount;
  final bool isToday;
  final bool isExpanded;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasData = sessionCount > 0;
    final numberColor = isFuture
        ? AppPalette.textMuted.withValues(alpha: 0.5)
        : (isToday ? AppPalette.textPrimary : AppPalette.textSecondary);

    final content = Container(
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        // accentStrong at low opacity marks the day whose detail is open --
        // the same borrowed-opacity trick the PB pill on a session row uses,
        // rather than introducing a selection colour nowhere else in the app.
        color: isExpanded
            ? AppPalette.accentStrong.withValues(alpha: 0.14)
            : null,
        border: isToday
            ? Border.all(color: AppPalette.accentStrong, width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$day',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
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
                      for (var i = 0; i < (sessionCount > 1 ? 2 : 1); i++)
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
    );

    if (!hasData) {
      return Semantics(label: '$day, no workout logged', child: content);
    }

    return Semantics(
      button: true,
      label: '$day, ${sessionCount == 1 ? '1 workout' : '$sessionCount workouts'}'
          '${isExpanded ? ', open' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
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

  static const _abbr = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final label = '${_abbr[day.month - 1]} ${day.day}, ${day.year}'
        '${sessions.length > 1 ? ' · ${sessions.length} sessions' : ''}';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 10),
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
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
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
