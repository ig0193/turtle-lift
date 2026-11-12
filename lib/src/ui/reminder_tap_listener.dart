import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../data/glance_bridge.dart';
import '../data/reminder_scheduler.dart';
import '../data/training_plan.dart' show planTodayProvider;
import 'diet_pane.dart' show dietSelectedDayProvider;
import 'profile_root.dart';
import 'tab_index.dart';
import 'tab_routes.dart';

export 'tab_routes.dart' show kProfileTabIndex, kWorkoutTabIndex;

/// The Profile segment a reminder [target] opens, or null when it opens a
/// different tab.
///
/// A training reminder opens the Workout tab, where training starts, not the
/// settings form that scheduled it (ADR 0008; HIG: a tap should "display
/// related content"). A diet reminder is about today's plan, which lives on
/// Profile › Diet.
ProfileSegment? _segmentFor(ReminderTarget target) => switch (target) {
      ReminderTarget.dietToday => ProfileSegment.diet,
      ReminderTarget.workout => null,
    };

int _tabFor(ReminderTarget target) =>
    _segmentFor(target) == null ? kWorkoutTabIndex : kProfileTabIndex;

/// Where the app opens when a notification launched it (KTD17, AE6).
///
/// Boot passes these to the **first** `ProviderScope` only. They change what
/// the tab index and the Profile segment build to, so the first frame is
/// already Profile, Diet, with no swap a frame later; the user can move away
/// as usual. The reboot after Delete all data passes no target, because the
/// plugin reports the same launch for the whole process and would otherwise
/// put a wiped app back on Diet (AE8).
List<Override> reminderLaunchOverrides(ReminderTarget? target) {
  if (target == null) return const <Override>[];
  final segment = _segmentFor(target);
  return <Override>[
    tabIndexProvider.overrideWith(() => _LaunchTabIndex(_tabFor(target))),
    if (segment != null)
      profileSegmentProvider.overrideWith(() => _LaunchSegment(segment)),
  ];
}

class _LaunchTabIndex extends TabIndex {
  _LaunchTabIndex(this._initial);

  final int _initial;

  @override
  int build() => _initial;
}

class _LaunchSegment extends ProfileSegmentNotifier {
  _LaunchSegment(this._initial);

  final ProfileSegment _initial;

  @override
  ProfileSegment build() => _initial;
}

/// Routes reminder taps while the app is running (KTD17, R11).
///
/// **It sits on the shell's own route** (`TurtleLiftApp.home`), so the route
/// it captures is the shell route and the pop predicate is that route, never
/// `isFirst`: a splash added in front later must not become the pop target.
/// Popping first closes any pushed screen, dialog or bottom sheet, so a tab
/// switch only ever happens with an empty stack (ADR 0003).
///
/// A diet tap also resets Diet's selected day to today (KTD17), so a day the
/// user had picked earlier does not hide the plan the reminder was about. A
/// cold start needs nothing: the selected day defaults to today.
class ReminderTapListener extends ConsumerStatefulWidget {
  const ReminderTapListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderTapListener> createState() =>
      _ReminderTapListenerState();
}

class _ReminderTapListenerState extends ConsumerState<ReminderTapListener> {
  StreamSubscription<ReminderTarget>? _taps;
  StreamSubscription<void>? _glanceTaps;
  ModalRoute<Object?>? _shellRoute;

  @override
  void initState() {
    super.initState();
    _taps = ref.read(reminderSchedulerProvider).taps.listen(_route);
    // A tap on the Live Activity or the home-screen widget lands where a
    // training reminder does: the Workout tab (ADR 0008).
    _glanceTaps = ref
        .read(glanceBridgeProvider)
        .openWorkoutTaps
        .listen((_) => _route(ReminderTarget.workout));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shellRoute = ModalRoute.of(context);
  }

  void _route(ReminderTarget target) {
    if (!mounted) return;
    final shell = _shellRoute;
    if (shell != null) {
      Navigator.of(context).popUntil((route) => route == shell);
    }
    final segment = _segmentFor(target);
    if (segment == null) {
      ref.read(tabIndexProvider.notifier).select(_tabFor(target));
    } else {
      showProfileSegment(ref, segment);
    }
    if (target == ReminderTarget.dietToday) {
      // A diet reminder is about today's plan, whatever day was picked.
      ref
          .read(dietSelectedDayProvider.notifier)
          .select(ref.read(planTodayProvider));
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    _glanceTaps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
