import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../theme/app_palette.dart';
import 'destructive_confirmation.dart';

/// Finish and Discard, the two ways a workout ends.
///
/// **Finish is the primary action and Discard is not.** Ending a workout and
/// throwing it away are different things, so they do not look alike: Discard is
/// a quiet surface, and its confirmation is painted in the destructive colour.
///
/// **A workout with no completed sets is never saved.** It is dropped silently
/// when nothing was ever written, and after a confirmation when the user typed
/// values without ticking them — the app commits every keystroke precisely so
/// that typed work survives, and throwing it away unannounced would spend that
/// guarantee on nothing.
class SessionActions extends ConsumerWidget {
  const SessionActions({required this.onFinished, super.key});

  /// Called once the workout has been saved, so the screen can show its
  /// summary. Not called when nothing was saved.
  final void Function(String sessionId) onFinished;

  /// The key a test taps to finish.
  static const Key finishKey = ValueKey<String>('finish-workout');

  /// The key a test taps to discard.
  static const Key discardKey = ValueKey<String>('discard-workout');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton(
          key: finishKey,
          onPressed: () => _finish(context, ref),
          child: const Text('Finish workout'),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: 'Discard workout',
          excludeSemantics: true,
          child: GestureDetector(
            key: discardKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => _discard(context, ref),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.surface,
                border: Border.all(color: AppPalette.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Discard workout',
                style:
                    TextStyle(fontSize: 14, color: AppPalette.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;

    final sessionId = session.id;
    if (setCountOf(session) == 0) {
      // Nothing completed, so nothing to save. Ask first when the user typed
      // values they simply never ticked.
      if (session.hasAnyWrittenSets) {
        final confirmed = await confirmDestructive(
          context,
          title: 'Nothing completed',
          message: 'This workout has values typed but no sets ticked, so there '
              'is nothing to save. Discard it?',
          confirmLabel: 'Discard',
        );
        if (!confirmed) return;
      }
      await ref.read(activeSessionProvider.notifier).discard();
      return;
    }

    await ref.read(activeSessionProvider.notifier).finish();
    onFinished(sessionId);
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Discard workout?',
      message: 'This permanently drops this workout and every set in it.',
      confirmLabel: 'Discard',
    );
    if (!confirmed) return;
    await ref.read(activeSessionProvider.notifier).discard();
  }
}
