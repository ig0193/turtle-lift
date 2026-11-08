import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../data/reminder_scheduler.dart';
import '../data/training_plan.dart' show planTodayProvider;
import 'diet_pane.dart' show dietSelectedDayProvider;
import 'l0_shell.dart';
import 'profile_root.dart';
import 'tab_index.dart';

/// The Profile tab's index, read off the shell's own tab list so a reordered
/// bar cannot leave a reminder opening the wrong tab.
final int kProfileTabIndex =
    L0Shell.tabs.indexWhere((tab) => tab.body is ProfileRoot);

/// The Profile segment a reminder [target] opens.
ProfileSegment _segmentFor(ReminderTarget target) => switch (target) {
      ReminderTarget.dietToday => ProfileSegment.diet,
      ReminderTarget.schedule => ProfileSegment.schedule,
    };

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
    tabIndexProvider.overrideWith(() => _LaunchTabIndex(kProfileTabIndex)),
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
  ModalRoute<Object?>? _shellRoute;

  @override
  void initState() {
    super.initState();
    _taps = ref.read(reminderSchedulerProvider).taps.listen(_route);
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
    ref.read(tabIndexProvider.notifier).select(kProfileTabIndex);
    ref.read(profileSegmentProvider.notifier).select(_segmentFor(target));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
