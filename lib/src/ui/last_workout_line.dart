import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_preview_data.dart';
import '../theme/app_palette.dart';
import 'history_session_detail_screen.dart';
import 'history_session_row.dart' show historyDateLabel;

/// The newest saved workout as one line, which opens it in History.
///
/// **A pointer to History, not a second stat.** It repeats exactly what that
/// workout's History row says (day, name, sets) and opens the same detail
/// screen, so there is no figure here that History does not own. It never
/// suggests repeating it.
class LastWorkoutLine extends ConsumerWidget {
  const LastWorkoutLine({super.key});

  static const Key lineKey = ValueKey<String>('last-workout');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastWorkoutProvider);
    if (last == null) return const SizedBox.shrink();
    final line = last.line;
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: HistorySessionDetailScreen.routeNameFor(last.id),
            ),
            builder: (_) => HistorySessionDetailScreen(sessionId: last.id),
          ),
        );

    return Semantics(
      container: true,
      button: true,
      label: 'Last workout: $line',
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        key: lineKey,
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: <Widget>[
              const Text(
                'Last workout',
                style: TextStyle(fontSize: 13, color: AppPalette.textMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textSecondary,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppPalette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The newest saved workout as "Yesterday · Push day · 14 sets", with its id,
/// or null with no history. Shared by [LastWorkoutLine] and the home-screen
/// widget, so the two can never word it differently.
final lastWorkoutProvider = Provider<({String id, String line})?>((ref) {
  final sessions = ref.watch(historySessionsNewestFirstProvider);
  if (sessions.isEmpty) return null;
  final session = sessions.first;
  final figures = ref.watch(historyProjectionProvider)[session.id];
  if (figures == null) return null;
  final sets = '${figures.setCount} set${figures.setCount == 1 ? '' : 's'}';
  return (
    id: session.id,
    line: '${historyDateLabel(session.performedOn)} · '
        '${resolvedTitle(session, figures)} · $sets',
  );
});
