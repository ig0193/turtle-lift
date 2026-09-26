import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/set_format.dart';
import 'tab_index.dart';
import '../theme/app_palette.dart';
import 'rest_timer.dart';

/// What sits above the tab bar while a workout is running and the user is
/// looking at something else.
///
/// **It only appears off the Workout tab.** On the Workout tab the workout *is*
/// the screen (`docs/02` Step 2b), so a bar announcing it would be a label on
/// the thing you are already looking at. Leaving the tab is what Hevy's
/// collapse chevron does; here the tab bar already does it, so the bar is the
/// other half of that gesture rather than a second control for it.
///
/// **The rest countdown outranks it.** Both cannot occupy the strip, and a
/// running rest is the time-critical one — the workout is not going anywhere.
class MiniWorkoutBar extends ConsumerWidget {
  const MiniWorkoutBar({super.key});

  static const Key barKey = ValueKey<String>('mini-workout-bar');

  /// The Workout tab's index in the shell. The bar hides on it.
  static const int workoutTabIndex = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final restTimer = ref.watch(restTimerProvider);
    if (restTimer != null) return const RestTimerBar();

    final tab = ref.watch(tabIndexProvider);
    if (session == null || tab == workoutTabIndex) {
      return const SizedBox.shrink();
    }

    final index = ref.watch(exerciseIndexProvider);
    return Material(
      key: barKey,
      color: AppPalette.surface,
      child: InkWell(
        onTap: () =>
            ref.read(tabIndexProvider.notifier).select(workoutTabIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              const Icon(Icons.fitness_center,
                  size: 18, color: AppPalette.accentStrong),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  resolvedTitle(session, index),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const _Elapsed(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Elapsed extends ConsumerStatefulWidget {
  const _Elapsed();

  @override
  ConsumerState<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends ConsumerState<_Elapsed> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final elapsed = session == null ? null : elapsedOf(session, _now);
    if (elapsed == null) return const SizedBox.shrink();
    return Text(
      formatDuration(elapsed.inSeconds),
      style: const TextStyle(
        color: AppPalette.accentLight,
        fontWeight: FontWeight.w600,
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}
