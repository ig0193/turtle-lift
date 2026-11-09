/// One free-text note per exercise per session, and the "last time" hint
/// derived from it (`docs/adr/0011-combined-build-decisions.md`).
///
/// **The note is entered data; the hint is derived.** Only
/// `session_exercises.note` is stored. What set logging shows as "Last time"
/// is read from saved sessions on every build, so editing or deleting an old
/// workout changes it with nothing to refresh.
library;

import 'session_store.dart';

/// Longest note kept. A note is a reminder ("seat 4, pin 7"), not a diary, and
/// it has to fit under an exercise name in History without taking the row
/// over.
const int kExerciseNoteMax = 120;

/// The note as stored: trimmed, capped, and `null` when blank, so "no note"
/// has exactly one representation.
String? normaliseNote(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed.length <= kExerciseNoteMax
      ? trimmed
      : trimmed.substring(0, kExerciseNoteMax).trimRight();
}

/// The note on [exerciseId] in the most recent saved session before
/// [current] that has one, or null.
///
/// A later session with no note does not hide an older one: a seat height
/// noted once is still the seat height. Sessions are compared by calendar day,
/// then by when they were logged, the same order History lists them in.
String? lastNoteFor(
  List<WorkoutSession> saved,
  String exerciseId, {
  required WorkoutSession current,
}) {
  WorkoutSession? best;
  String? note;
  for (final session in saved) {
    if (session.id == current.id || _before(current, session)) continue;
    for (final exercise in session.exercises) {
      if (exercise.exerciseId != exerciseId || exercise.note == null) continue;
      if (best == null || _before(best, session)) {
        best = session;
        note = exercise.note;
      }
    }
  }
  return note;
}

bool _before(WorkoutSession a, WorkoutSession b) {
  final byDay = a.performedOn.compareTo(b.performedOn);
  if (byDay != 0) return byDay < 0;
  return a.loggedAt.isBefore(b.loggedAt);
}

/// [ids] with the entry at [index] replaced by [replacement], for the
/// template editor's swap. Unchanged when [replacement] is already in the
/// list: one exercise appears once.
List<String> swapInList(List<String> ids, int index, String replacement) {
  if (index < 0 || index >= ids.length || ids.contains(replacement)) {
    return List<String>.of(ids);
  }
  return <String>[...ids]..[index] = replacement;
}
