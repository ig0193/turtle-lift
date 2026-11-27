import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../data/glance_bridge.dart';
import '../data/reminder_scheduler.dart';
import '../data/today.dart' show planTodayProvider;
import 'diet_pane.dart' show showDietDay;
import 'tab_index.dart';
import 'tab_routes.dart';

export 'tab_routes.dart' show kDietTabIndex, kWorkoutTabIndex;

/// The tab a reminder [target] opens.
///
/// A diet reminder is about today's log, which is the Diet tab
/// (`docs/adr/0016-you-tab-and-diet-tab.md`). The Workout target (a Live
/// Activity or widget tap, or a training notification an earlier build already
/// delivered) opens the Workout tab, where training starts.
int _tabFor(ReminderTarget target) => switch (target) {
      ReminderTarget.dietToday => kDietTabIndex,
      ReminderTarget.workout => kWorkoutTabIndex,
    };

/// Where the app opens when a notification launched it (KTD17, AE6).
///
/// Boot passes these to the **first** `ProviderScope` only. They change what
/// the tab index builds to, so the first frame is already the Diet tab, with no
/// swap a frame later; the user can move away as usual. The reboot after
/// Delete all data passes no target, because the plugin reports the same
/// launch for the whole process and would otherwise put a wiped app back on
/// Diet (AE8).
List<Override> reminderLaunchOverrides(ReminderTarget? target) {
  if (target == null) return const <Override>[];
  return <Override>[
    tabIndexProvider.overrideWith(() => _LaunchTabIndex(_tabFor(target))),
  ];
}

class _LaunchTabIndex extends TabIndex {
  _LaunchTabIndex(this._initial);

  final int _initial;

  @override
  int build() => _initial;
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
/// user had picked earlier does not hide the day the reminder was about. A
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
    // A tap on the Live Activity or the home-screen widget lands on the
    // Workout tab (ADR 0008).
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
    ref.read(tabIndexProvider.notifier).select(_tabFor(target));
    if (target == ReminderTarget.dietToday) {
      // A diet reminder is about today's log, whatever day was picked, and
      // today's week comes back into the strip with it.
      showDietDay(ref, ref.read(planTodayProvider));
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
