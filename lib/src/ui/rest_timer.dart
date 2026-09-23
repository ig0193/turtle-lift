import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';

/// The rest timer's live state. Null means nothing is resting.
@immutable
class RestTimerState {
  const RestTimerState({required this.total, required this.remaining});

  final int total;
  final int remaining;

  double get progress => total == 0 ? 0 : remaining / total;
}

/// The one running rest timer.
///
/// **One at a time, deliberately.** Two exercises resting at once would need
/// two countdowns on screen competing for the same glance, and the user is
/// resting from one set. Starting a new rest replaces the old one.
///
/// **Foreground only, and it raises no notification.** `00` §13 still bans
/// notifications; the rest timer left that list, the notification ban did not
/// (`adr/0004`). A timer that fires while the app is backgrounded would need
/// one, so it simply does not claim to.
class RestTimer extends Notifier<RestTimerState?> {
  Timer? _ticker;

  @override
  RestTimerState? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  void start(int seconds) {
    _ticker?.cancel();
    state = RestTimerState(total: seconds, remaining: seconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (current == null) return;
      if (current.remaining <= 1) {
        stop();
        return;
      }
      state = RestTimerState(
        total: current.total,
        remaining: current.remaining - 1,
      );
    });
  }

  /// Adds or removes time mid-rest. Never below zero, and never a rest that
  /// has already finished.
  void adjust(int deltaSeconds) {
    final current = state;
    if (current == null) return;
    final remaining = current.remaining + deltaSeconds;
    if (remaining <= 0) {
      stop();
      return;
    }
    state = RestTimerState(
      total: current.total > remaining ? current.total : remaining,
      remaining: remaining,
    );
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    state = null;
  }
}

final restTimerProvider =
    NotifierProvider<RestTimer, RestTimerState?>(RestTimer.new);

/// The `Rest timer: OFF` line under an exercise's title.
///
/// Off is the default and stays the default: most sets do not want a countdown,
/// and one that armed itself would start a clock the user never asked for.
class RestTimerLine extends ConsumerWidget {
  const RestTimerLine({required this.exercise, super.key});

  final SessionExercise exercise;

  static Key lineKey(String exerciseRowId) =>
      ValueKey<String>('rest-timer-$exerciseRowId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = exercise.restTimerSec;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: lineKey(exercise.id),
        onPressed: () => _pick(context, ref),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.timer_outlined,
            size: 16, color: AppPalette.textSecondary),
        label: Text(
          seconds == null
              ? 'Rest timer: OFF'
              : 'Rest timer: ${formatDuration(seconds)}',
          style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    const options = <int?>[null, 30, 45, 60, 90, 120, 180];
    final chosen = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: AppPalette.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Rest timer',
                  style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            // **Flexible and scrollable, not a bare column of seven rows.** A
            // bottom sheet is capped at a fraction of the viewport, so seven
            // tiles overflow on a short screen or at a large text size — and an
            // overflowing sheet is red stripes, not a tight layout.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final option in options)
                    ListTile(
                      title: Text(
                        option == null ? 'Off' : formatDuration(option),
                        style: const TextStyle(color: AppPalette.textPrimary),
                      ),
                      trailing: option == exercise.restTimerSec
                          ? const Icon(Icons.check,
                              color: AppPalette.accentStrong)
                          : null,
                      onTap: () => Navigator.of(context).pop(<Object?>[option]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen is! List<Object?>) return;
    await ref.read(activeSessionProvider.notifier).setExerciseRestTimer(
          sessionExerciseId: exercise.id,
          seconds: chosen.first as int?,
        );
  }
}

/// The countdown bar shown while a rest is running.
///
/// A bar, not a ring: `02` still rules out a rest-timer ring animation, and a
/// bar reads at a glance from across a gym floor without drawing the eye.
class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  static const Key barKey = ValueKey<String>('rest-timer-bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    if (timer == null) return const SizedBox.shrink();

    return Container(
      key: barKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppPalette.surface,
      child: Row(
        children: <Widget>[
          Text(
            formatDuration(timer.remaining),
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: timer.progress,
              backgroundColor: AppPalette.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppPalette.accentStrong),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(restTimerProvider.notifier).adjust(-15),
            child: const Text('-15',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
          TextButton(
            onPressed: () => ref.read(restTimerProvider.notifier).adjust(15),
            child: const Text('+15',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
          TextButton(
            onPressed: () => ref.read(restTimerProvider.notifier).stop(),
            child: const Text('Skip',
                style: TextStyle(color: AppPalette.accentLight)),
          ),
        ],
      ),
    );
  }
}
