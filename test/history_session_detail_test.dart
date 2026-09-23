import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/data/set_format.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/history_session_detail_screen.dart';

/// How a past workout reads.
///
/// **Both tests here are about the app saying one thing in two places.** The
/// detail screen and the post-workout summary card render the same sets; when
/// the detail screen formatted them itself it showed `15.5 kg` beside the
/// summary's `15.5kg × 10`, and a user comparing the two had to work out that
/// they agreed. And the screen carried a note calling this data a sample, which
/// stopped being true the moment the sessions became real.
void main() {
  HistorySession detailSession(List<String> labels, List<double> scores) =>
      HistorySession(
        id: 's1',
        performedOn: DateTime.now(),
        title: 'Push day',
        isQuickLog: false,
        exercises: <HistoryExercise>[
          HistoryExercise(
            name: 'Bench press',
            primaryGroupIds: const <String>['chest'],
            setScores: scores,
            setLabels: labels,
          ),
        ],
      );

  Future<void> show(WidgetTester tester, HistorySession session) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historySessionsProvider.overrideWithValue(<HistorySession>[session]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const HistorySessionDetailScreen(sessionId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a set reads exactly as the summary card wrote it', (
    tester,
  ) async {
    await show(
      tester,
      detailSession(
        const <String>['60kg × 8', '62.5kg × 6'],
        const <double>[60, 62.5],
      ),
    );

    expect(find.text('60kg × 8'), findsOneWidget);
    expect(find.text('62.5kg × 6'), findsOneWidget);
    expect(
      find.text('60 kg'),
      findsNothing,
      reason: 'the weight alone drops the reps and invents a second format',
    );
  });

  testWidgets('an assisted set keeps its wording, not its comparison score', (
    tester,
  ) async {
    // Assisted scores are negated so that less help sorts as better. Rendering
    // that number would put "-20 kg" on screen.
    const set = SetEntry(
      id: 'x',
      position: 1,
      assistKg: 20,
      reps: 8,
      completed: true,
    );
    final label = formatSet(LoadType.assisted, set);

    await show(tester, detailSession(<String>[label], const <double>[-20]));

    expect(find.text(label), findsOneWidget);
    expect(find.textContaining('-20'), findsNothing);
  });

  testWidgets('it no longer calls the user\'s workouts sample data', (
    tester,
  ) async {
    await show(tester, detailSession(const <String>['60kg × 8'], const [60]));

    expect(find.textContaining('sample data'), findsNothing);
    expect(
      find.textContaining('Editing and deleting a past workout arrive'),
      findsNothing,
      reason: 'editing a saved session shipped with the session flow',
    );
  });
}
