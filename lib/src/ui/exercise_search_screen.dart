import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/load_type.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'exercise_detail_screen.dart';
import 'muscle_exercise_list_screen.dart' show ExerciseRow;
import 'muscle_search_field.dart';
import 'set_logging_screen.dart';

/// Search the library and add what you want. The ad-hoc path's way in.
///
/// **The session is created by the first exercise added, not by arriving
/// here.** Creating it on the tap would strand a user who backs out with
/// nothing added in an empty workout that has replaced their landing, whose
/// only exits are Discard or starting another one.
///
/// **One vocabulary, not three.** The Muscles tab's search spans exercise
/// names, muscle labels and equipment because browsing is its job. This screen
/// is adding an exercise to a workout, so it searches exercise names.
class ExerciseSearchScreen extends ConsumerStatefulWidget {
  const ExerciseSearchScreen({super.key});

  /// The key a test finds the result count by.
  static const Key countKey = ValueKey<String>('search-match-count');

  @override
  ConsumerState<ExerciseSearchScreen> createState() =>
      _ExerciseSearchScreenState();
}

class _ExerciseSearchScreenState extends ConsumerState<ExerciseSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(exerciseIndexProvider);
    final saved = ref.watch(savedSessionsProvider);
    final results = index.searchByName(_query);

    return AppScreen.pushed(
      title: 'Add exercise',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 12),
          MuscleSearchField.editable(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          if (_query.trim().isNotEmpty)
            Padding(
              key: ExerciseSearchScreen.countKey,
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${results.length} ${results.length == 1 ? 'match' : 'matches'}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppPalette.textMuted,
                ),
              ),
            ),
          for (final exercise in results)
            _ResultRow(
              exercise: exercise,
              lastSet: _lastSetLine(exercise, saved),
              onTap: () => _add(exercise, saved),
            ),
        ],
      ),
    );
  }

  /// What the user last did with this exercise, or null when they never have.
  String? _lastSetLine(Exercise exercise, List<WorkoutSession> saved) {
    final last = lastSessionOf(exercise.id, saved);
    if (last == null) return null;
    final logged =
        last.exercises.firstWhere((e) => e.exerciseId == exercise.id);
    final completed = logged.completedSets.toList();
    if (completed.isEmpty) return null;
    return 'Last ${formatSet(logged.loadType, completed.last)}';
  }

  /// Adds [exercise] and goes where the user should go next.
  ///
  /// Creates the workout if this is the first add. An exercise the user has
  /// never completed lands on its page first — they cannot know a lift they
  /// have never done — and one already in this workout opens rather than
  /// duplicating, which would split its sets across two prefill chains.
  Future<void> _add(Exercise exercise, List<WorkoutSession> saved) async {
    final loadType = LoadType.fromName(exercise.loadType);
    if (loadType == null) return;

    final notifier = ref.read(activeSessionProvider.notifier);
    var session = ref.read(activeSessionProvider);
    if (session == null) {
      await notifier.startAdHoc();
      session = ref.read(activeSessionProvider);
      if (session == null) return;
    }

    final alreadyHere =
        session.exercises.any((e) => e.exerciseId == exercise.id);
    final neverDone = timesPerformed(exercise.id, saved) == 0;

    if (neverDone && !alreadyHere) {
      if (!mounted) return;
      await pushExerciseDetail(context, exercise,
          entry: ExerciseDetailEntry.workoutStart);
      return;
    }

    final rowId = await notifier.addExercise(
      exerciseId: exercise.id,
      loadType: loadType,
    );
    if (rowId == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SetLoggingScreen(sessionExerciseId: rowId),
      ),
    );
  }
}

/// One result: the exercise, its equipment, and what the user last did with it.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.exercise,
    required this.lastSet,
    required this.onTap,
  });

  final Exercise exercise;
  final String? lastSet;
  final VoidCallback onTap;

  /// The key a test taps to add [id].
  static Key rowKey(String id) => ValueKey<String>('search-result-$id');

  @override
  Widget build(BuildContext context) {
    return Column(
      key: rowKey(exercise.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExerciseRow(
          name: exercise.name,
          equipment: exercise.equipment,
          onTap: onTap,
        ),
        if (lastSet != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              lastSet!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppPalette.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}
