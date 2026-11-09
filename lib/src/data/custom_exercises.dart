import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'custom_templates.dart' show customTemplateListProvider;
import 'exercise.dart';
import 'generated/muscle_taxonomy.dart';
import 'load_type.dart';
import 'settings_store.dart' show appDatabaseProvider;

/// The user's own exercises (`docs/adr/0009-custom-exercises-and-template-editing.md`).
///
/// **A custom exercise is an [Exercise] with `isCustom: true` and no reviewed
/// content.** Once it is in the index ([exerciseIndexProvider]) every screen
/// that looks an exercise up by id — the picker, templates, the session, set
/// logging, history, records, export — treats it like a library one, because
/// everything about a logged exercise is derived from the session tables and
/// the id. The four content fields stay empty: the app never writes
/// instructions it has not had reviewed.

/// The prefix every custom id carries, and no library id does.
const String kCustomExerciseIdPrefix = 'custom-';

/// Longest name accepted, matching the session title cap's spirit: it has to
/// fit a row, a template tile and a share card line.
const int kCustomExerciseNameMax = 40;

/// Whether [id] names a user-created exercise.
bool isCustomExerciseId(String id) => id.startsWith(kCustomExerciseIdPrefix);

/// Reads and writes the `custom_exercises` table. Widgets go through
/// [CustomExerciseList]; nothing outside this file learns the columns.
class CustomExerciseStore {
  const CustomExerciseStore(this._db);

  final AppDatabase _db;

  /// Every custom exercise, by name then id, so the order a write leaves in
  /// memory is the order the next launch reads.
  Future<List<CustomExerciseRow>> readAll() => (_db.select(_db.customExercises)
        ..orderBy(<OrderingTerm Function($CustomExercisesTable)>[
          (t) => OrderingTerm.asc(t.name),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .get();

  Future<void> upsert(Exercise exercise) async {
    await _db.into(_db.customExercises).insertOnConflictUpdate(
          CustomExercisesCompanion.insert(
            id: exercise.id,
            name: exercise.name,
            equipment: exercise.equipment,
            loadType: exercise.loadType,
            primaryIds: exercise.primary.join(','),
            secondaryIds: Value<String>(exercise.secondary.join(',')),
            hidden: Value<bool>(exercise.hidden),
          ),
        );
  }

  Future<void> setHidden(String id, bool hidden) async {
    await (_db.update(_db.customExercises)..where((t) => t.id.equals(id)))
        .write(CustomExercisesCompanion(hidden: Value<bool>(hidden)));
  }

  /// Deletes the exercise and takes it out of every custom template, in one
  /// transaction, so no template is left naming an exercise that is gone.
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.customExercises)..where((t) => t.id.equals(id)))
          .go();
      final templates = await _db.select(_db.customTemplates).get();
      for (final template in templates) {
        final ids = template.exerciseIds.isEmpty
            ? const <String>[]
            : template.exerciseIds.split(',');
        if (!ids.contains(id)) continue;
        await (_db.update(_db.customTemplates)
              ..where((t) => t.id.equals(template.id)))
            .write(CustomTemplatesCompanion(
          exerciseIds: Value<String>(ids.where((e) => e != id).join(',')),
        ));
      }
    });
  }

  /// Whether any session — open or saved — logs [id]. A logged exercise
  /// cannot be deleted (its history would lose its name) and its load type is
  /// fixed (its records would compare across two kinds of number).
  Future<bool> isLogged(String id) async {
    final row = await (_db.select(_db.sessionExercises)
          ..where((e) => e.exerciseId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }
}

final customExerciseStoreProvider = Provider<CustomExerciseStore>(
  (ref) => CustomExerciseStore(ref.watch(appDatabaseProvider)),
);

/// One stored row as the [Exercise] the rest of the app reads.
Exercise exerciseFromCustomRow(CustomExerciseRow row) => Exercise(
      id: row.id,
      name: row.name,
      equipment: row.equipment,
      loadType: row.loadType,
      primary: _split(row.primaryIds),
      secondary: _split(row.secondaryIds),
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
      isCustom: true,
      hidden: row.hidden,
    );

List<String> _split(String stored) =>
    stored.isEmpty ? const <String>[] : stored.split(',');

/// Reads the table before the first frame, degrading to none rather than
/// stopping the app: a row this build cannot read must not cost the user the
/// app.
Future<List<Exercise>> readStoredCustomExercises(
  CustomExerciseStore store,
) async {
  try {
    final rows = await store.readAll();
    return rows.map(exerciseFromCustomRow).toList(growable: false);
  } catch (_) {
    return const <Exercise>[];
  }
}

/// The custom exercises the app booted with. Overridden by `main()`, like
/// `initialCustomTemplatesProvider`, so the first frame already has them.
final initialCustomExercisesProvider =
    Provider<List<Exercise>>((ref) => const <Exercise>[]);

/// What the editor hands back: everything the user types, nothing derived.
class CustomExerciseDraft {
  const CustomExerciseDraft({
    required this.name,
    required this.equipment,
    required this.loadType,
    required this.primary,
    this.secondary = const <String>[],
  });

  final String name;
  final String equipment;
  final LoadType loadType;
  final List<String> primary;
  final List<String> secondary;

  /// Why this draft cannot be saved, or null when it can.
  String? get problem {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Give it a name.';
    if (trimmed.length > kCustomExerciseNameMax) {
      return 'Keep the name to $kCustomExerciseNameMax characters.';
    }
    if (primary.isEmpty) return 'Pick at least one main muscle.';
    for (final id in <String>[...primary, ...secondary]) {
      if (!kSubMuscleGroups.containsKey(id)) return 'Unknown muscle: $id';
    }
    return null;
  }
}

/// The user's exercises, and the only way to change them.
///
/// Writes the database first and then the state, like `CustomTemplateList`.
class CustomExerciseList extends Notifier<List<Exercise>> {
  @override
  List<Exercise> build() => ref.read(initialCustomExercisesProvider);

  CustomExerciseStore get _store => ref.read(customExerciseStoreProvider);

  /// Creates an exercise from [draft] and returns it. The id is minted here
  /// and always carries [kCustomExerciseIdPrefix].
  Future<Exercise> add(CustomExerciseDraft draft) async {
    final problem = draft.problem;
    if (problem != null) throw ArgumentError(problem);
    final exercise = _toExercise('$kCustomExerciseIdPrefix${const Uuid().v4()}',
        draft);
    await _store.upsert(exercise);
    state = _sorted(<Exercise>[...state, exercise]);
    return exercise;
  }

  /// Replaces the exercise with [id]. The load type is kept as it was when the
  /// exercise is already logged, whatever [draft] says.
  Future<Exercise?> edit(String id, CustomExerciseDraft draft) async {
    final problem = draft.problem;
    if (problem != null) throw ArgumentError(problem);
    final current = state.where((e) => e.id == id).firstOrNull;
    if (current == null) return null;
    final locked = await _store.isLogged(id);
    final exercise = _toExercise(
      id,
      draft,
      loadTypeName: locked ? current.loadType : draft.loadType.name,
      hidden: current.hidden,
    );
    await _store.upsert(exercise);
    state = _sorted(<Exercise>[
      for (final e in state)
        if (e.id == id) exercise else e,
    ]);
    return exercise;
  }

  /// Whether the exercise appears in any workout. See
  /// [CustomExerciseStore.isLogged].
  Future<bool> isLogged(String id) => _store.isLogged(id);

  /// Deletes an exercise no workout logs, and removes it from every custom
  /// template. Returns false, and deletes nothing, when a workout logs it.
  Future<bool> delete(String id) async {
    if (await _store.isLogged(id)) return false;
    await _store.delete(id);
    ref.read(customTemplateListProvider.notifier).forgetExercise(id);
    state = <Exercise>[
      for (final e in state)
        if (e.id != id) e,
    ];
    return true;
  }

  /// Hides the exercise from the picker, or shows it again. The way to
  /// retire a logged exercise, which [delete] refuses: it stays in History,
  /// records and export.
  Future<void> setHidden(String id, bool hidden) async {
    final current = state.where((e) => e.id == id).firstOrNull;
    if (current == null) return;
    await _store.setHidden(id, hidden);
    state = <Exercise>[
      for (final e in state)
        if (e.id == id) _withHidden(e, hidden) else e,
    ];
  }

  static Exercise _withHidden(Exercise e, bool hidden) => Exercise(
        id: e.id,
        name: e.name,
        equipment: e.equipment,
        loadType: e.loadType,
        primary: e.primary,
        secondary: e.secondary,
        setup: e.setup,
        posture: e.posture,
        execution: e.execution,
        commonMistakes: e.commonMistakes,
        isCustom: e.isCustom,
        hidden: hidden,
      );

  static Exercise _toExercise(
    String id,
    CustomExerciseDraft draft, {
    String? loadTypeName,
    bool hidden = false,
  }) {
    final primary = <String>[...{...draft.primary}];
    final secondary = <String>[
      for (final s in {...draft.secondary})
        if (!primary.contains(s)) s,
    ];
    return Exercise(
      id: id,
      name: draft.name.trim(),
      equipment: draft.equipment,
      loadType: loadTypeName ?? draft.loadType.name,
      primary: primary,
      secondary: secondary,
      setup: '',
      posture: '',
      execution: '',
      commonMistakes: '',
      isCustom: true,
      hidden: hidden,
    );
  }

  static List<Exercise> _sorted(List<Exercise> exercises) {
    final ordered = <Exercise>[...exercises]..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
    return List<Exercise>.unmodifiable(ordered);
  }
}

final customExerciseListProvider =
    NotifierProvider<CustomExerciseList, List<Exercise>>(
  CustomExerciseList.new,
);
