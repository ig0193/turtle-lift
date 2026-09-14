import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_index.dart';
import 'muscle_exercise_list_screen.dart';

/// Everything the library trains with one piece of equipment.
///
/// **The sub-group list's sibling, not a second kind of screen** (R13). It is
/// the same `AppScreen.pushed`, the same header, the same [ExerciseRow] and the
/// same destination for a tap; the only difference is which query filled it —
/// `withEquipment` rather than `withPrimary`. Written as a variant of
/// `MuscleExerciseListScreen` with a flag it would have had to carry a nullable
/// sub-group id *and* a nullable equipment value, and every line of it would
/// then have had to say which of the two it was in.
///
/// **It exists because search offers equipment as a result kind.** "kettlebell"
/// is a thing a user types when the rack is busy and a bell is not, and a
/// result that only led to the twelve exercises *named* after it would miss
/// nothing today and everything the moment a kettlebell lift is renamed.
///
/// **Nothing here is derived from training history**, for the reason
/// `MuscleExerciseListScreen` gives: the prototype's row carries a "last done"
/// line, and there is no session table to read it from.
class EquipmentExerciseListScreen extends ConsumerWidget {
  const EquipmentExerciseListScreen({required this.equipment, super.key});

  /// One of the library's own lower-case equipment values, as
  /// `ExerciseIndex.equipmentValues` reports them.
  final String equipment;

  /// The screen's title.
  ///
  /// **Capitalised, not upper-cased.** [exerciseEquipmentLabel] shouts because
  /// a chip is a tag read at a glance; a header is a name, and every other
  /// title in this tab is written the way the thing is called — "Lats",
  /// "Quads", "Barbell bench press". "KETTLEBELL" in the app bar would be the
  /// only screen in the app raising its voice.
  static String titleFor(String equipment) => equipment.isEmpty
      ? equipment
      : equipment[0].toUpperCase() + equipment.substring(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The muscle list's own body, reused rather than re-spelled: two screens
    // with the same shape must not count their rows in two different
    // sentences. Only the title and the query are this screen's own, and both
    // are resolved here before they are handed over — which is what keeps the
    // shared part from needing a nullable "which screen am I" to answer.
    return exerciseListScreen(
      context,
      title: titleFor(equipment),
      exercises: ref.watch(exerciseIndexProvider).withEquipment(equipment),
    );
  }
}

/// Pushes the list for [equipment].
///
/// **Opaque, like every push in this app (KTD9).** It is the only kind of route
/// that covers the floating tab bar; a sheet or a transparent route leaves
/// "Workout" painted over the exercises and one stray tap away.
Future<void> pushEquipmentExerciseList(
  BuildContext context,
  String equipment,
) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EquipmentExerciseListScreen(equipment: equipment),
      ),
    );
