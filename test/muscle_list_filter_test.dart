import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/active_session.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/equipment_exercise_list_screen.dart';
import 'package:turtle_lift/src/ui/muscle_exercise_list_screen.dart';

/// Equipment filter chips and the "last done" hint on exercise lists
/// (ADR 0012 decision 4 and 7).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseIndex index;
  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  Widget host(Widget child, {List<WorkoutSession> saved = const []}) =>
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          exerciseIndexProvider.overrideWithValue(index),
          initialSavedSessionsProvider.overrideWithValue(saved),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: child),
      );

  void tall(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 4000);
    addTearDown(tester.view.reset);
  }

  const glutes = MuscleExerciseListScreen(subGroupId: 'glutes/glutes');

  testWidgets('chips are the equipment the list uses, plus All',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(host(glutes));
    await tester.pump();
    final values = index
        .withPrimary('glutes/glutes')
        .map((e) => e.equipment)
        .toSet()
        .toList()
      ..sort();
    expect(find.byKey(equipmentChipKey(null)), findsOneWidget);
    for (final value in values) {
      expect(find.byKey(equipmentChipKey(value)), findsOneWidget,
          reason: value);
    }
    expect(find.byKey(equipmentChipKey('other')), findsNothing,
        reason: 'only values present in this list');
    final allChip = tester.getSemantics(find.byKey(equipmentChipKey(null)));
    expect(allChip, isSemantics(isSelected: true));
    expect(tester.getSize(find.byKey(equipmentChipKey('machine'))).width,
        lessThan(200), reason: 'a chip is as wide as its label, not the row');
  });

  testWidgets('choosing Machine shows only machine rows and counts them',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(host(glutes));
    await tester.pump();
    final machines = index
        .withPrimary('glutes/glutes')
        .where((e) => e.equipment == 'machine')
        .toList();
    await tester.tap(find.byKey(equipmentChipKey('machine')));
    await tester.pump();
    expect(find.byType(ExerciseRow), findsNWidgets(machines.length));
    expect(find.text(MuscleExerciseListScreen.countLabel(machines.length)),
        findsOneWidget);

    // Tapping it again clears the filter.
    await tester.tap(find.byKey(equipmentChipKey('machine')));
    await tester.pump();
    expect(find.byType(ExerciseRow),
        findsNWidgets(index.withPrimary('glutes/glutes').length));
  });

  testWidgets('the filter is not remembered: a fresh screen shows everything',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(host(glutes));
    await tester.pump();
    await tester.tap(find.byKey(equipmentChipKey('machine')));
    await tester.pump();
    await tester.pumpWidget(host(glutes));
    await tester.pump();
    expect(find.byType(ExerciseRow),
        findsNWidgets(index.withPrimary('glutes/glutes').length));
  });

  testWidgets('a single-equipment list has no chips', (tester) async {
    tall(tester);
    await tester.pumpWidget(
        host(const EquipmentExerciseListScreen(equipment: 'machine')));
    await tester.pump();
    expect(find.byKey(equipmentChipKey(null)), findsNothing);
  });

  testWidgets('a row with history says its last set', (tester) async {
    tall(tester);
    final thrust = index.byId('barbell-hip-thrust')!;
    final saved = <WorkoutSession>[
      WorkoutSession(
        id: 's',
        title: null,
        performedOn: const LocalDate(2026, 11, 9),
        loggedAt: DateTime(2026, 11, 9, 10),
        templateId: null,
        templateName: null,
        isOpen: false,
        exercises: [
          SessionExercise(
            id: 'x',
            exerciseId: thrust.id,
            position: 0,
            loadType: LoadType.weighted,
            markedDone: false,
            sets: const [
              SetEntry(
                  id: 'a', position: 0, completed: true, weightKg: 80, reps: 10),
            ],
          ),
        ],
      ),
    ];
    await tester.pumpWidget(host(glutes, saved: saved));
    await tester.pump();
    final row = find.byKey(exerciseRowKey(thrust.id));
    expect(
      find.descendant(of: row, matching: find.textContaining('Last 80')),
      findsOneWidget,
    );
  });
}
