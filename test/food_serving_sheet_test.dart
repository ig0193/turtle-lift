import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/diet_log.dart';
import 'package:turtle_lift/src/data/diet_log_store.dart';
import 'package:turtle_lift/src/data/food.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/today.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/diet_pane.dart';
import 'package:turtle_lift/src/ui/diet_slot_card.dart';
import 'package:turtle_lift/src/ui/food_picker_screen.dart';
import 'package:turtle_lift/src/ui/food_serving_sheet.dart';
import 'package:turtle_lift/src/ui/glass_tab_bar.dart';
import 'package:turtle_lift/src/ui/stepper_field.dart';

/// The serving sheet: add servings to one day's slot, or edit and remove with
/// undo. Fixture foods; "today" is Wednesday 4 November 2026, and the Diet
/// pane opens on it. Writes land in an in-memory database through a store
/// pinned to the same day.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LocalDate nov(int day) => LocalDate(2026, 11, day);

  Map<String, Object?> food(String id, String name, double protein,
          {String serving = '1 katori, 60 g'}) =>
      <String, Object?>{
        'id': id,
        'name': name,
        'aliases': const <String>[],
        'dietType': 'veg',
        'servingLabel': serving,
        'gramsPerServing': 60,
        'proteinPerServingG': protein,
        'proteinPer100g': protein,
        'ifctCode': 'X001',
        'reviewedBy': 'pending-owner-review',
      };

  final foods = FoodIndex.fromJson(<Map<String, Object?>>[
    food('paneer-bhurji', 'Paneer bhurji', 12.0),
    food('paneer', 'Paneer', 9.4, serving: '5 cubes, 50 g'),
  ]);
  final bhurji = foods.byId('paneer-bhurji')!;
  final paneer = foods.byId('paneer')!;

  late AppDatabase database;
  late DietLogStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = DietLogStore(database, today: () => nov(4));
  });
  tearDown(() => database.close());

  /// The app's shell shape: a root [AppScreen] with the floating tab bar,
  /// the Diet pane in a padded list, so the picker, the sheet and the
  /// snackbar all open over what a user sees.
  Widget host({List<DietLogEntry> log = const <DietLogEntry>[]}) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dietLogStoreProvider.overrideWithValue(store),
          foodIndexProvider.overrideWithValue(foods),
          planTodayProvider.overrideWithValue(nov(4)),
          initialDietLogProvider.overrideWithValue(log),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: AppScreen.root(
            title: 'Profile',
            extendBody: true,
            bottomBar: GlassTabBar(selectedIndex: 3, onSelected: (_) {}),
            body: Builder(
              builder: (context) => ListView(
                padding: screenScrollPadding(context),
                children: const <Widget>[DietPane()],
              ),
            ),
          ),
        ),
      );

  Future<void> pump(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  BuildContext paneContext(WidgetTester tester) =>
      tester.element(find.byType(DietPane));

  /// Opens the add sheet directly over the pane, as the picker does.
  Future<void> openAdd(WidgetTester tester, Food f,
      {LocalDate? date, MealSlot slot = MealSlot.lunch}) async {
    showAddFoodSheet(paneContext(tester),
        food: f, date: date ?? nov(4), slot: slot);
    await tester.pumpAndSettle();
  }

  Future<List<DietLogEntry>> storedEntries() => store.readEntries();

  Future<void> seed(LocalDate date, Food f, int halves,
      {MealSlot slot = MealSlot.lunch}) =>
      store.addFood(date: date, slot: slot, foodId: f.id, halves: halves);

  Finder stepperValue(String text) => find.descendant(
      of: find.byType(StepperField), matching: find.text(text));

  group('add mode', () {
    testWidgets('names the food and starts at one serving', (tester) async {
      await pump(tester, host());
      await openAdd(tester, bhurji);

      expect(find.byType(FoodServingSheet), findsOneWidget);
      expect(find.text('Paneer bhurji'), findsOneWidget);
      expect(stepperValue('1'), findsOneWidget);
      expect(find.text('1 katori, 12 g'), findsOneWidget);
      expect(find.text('Repeat on'), findsNothing,
          reason: 'Diet is a log: a food is logged on one day, never repeated');
      expect(
        find.descendant(
            of: find.byType(FilledButton), matching: find.text('Add to Lunch')),
        findsOneWidget,
      );
    });

    testWidgets('live protein follows the servings', (tester) async {
      await pump(tester, host());
      await openAdd(tester, bhurji);

      await tester.tap(find.bySemanticsLabel('Increase'));
      await tester.pumpAndSettle();
      expect(find.text('1.5 katori, 18 g'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Increase'));
      await tester.pumpAndSettle();
      expect(find.text('2 katori, 24 g'), findsOneWidget);
    });

    testWidgets('a serving label that is not one katori counts servings',
        (tester) async {
      await pump(tester, host());
      await openAdd(tester, paneer);
      expect(find.text('5 cubes, 9.4 g'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Increase'));
      await tester.pumpAndSettle();
      expect(find.text('1.5 × 5 cubes, 14.1 g'), findsOneWidget);
    });

    testWidgets('the stepper stops at 0.5 going down and at 4 going up',
        (tester) async {
      await pump(tester, host());
      await openAdd(tester, bhurji);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.bySemanticsLabel('Decrease'));
        await tester.pumpAndSettle();
      }
      expect(stepperValue('0.5'), findsOneWidget);
      expect(find.text('0.5 katori, 6 g'), findsOneWidget);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.bySemanticsLabel('Increase'));
        await tester.pumpAndSettle();
      }
      expect(stepperValue('4'), findsOneWidget);
      expect(find.text('4 katori, 48 g'), findsOneWidget);
    });

    testWidgets('Add logs the food on the date the sheet was opened for only',
        (tester) async {
      await pump(tester, host());
      await openAdd(tester, bhurji, date: nov(3));
      await tester.tap(find.byKey(FoodServingSheet.commitKey));
      await tester.pumpAndSettle();

      final entries = await storedEntries();
      expect(entries, hasLength(1));
      expect(entries.single.date, nov(3));
      expect(entries.single.slot, MealSlot.lunch);
      expect(entries.single.foodId, 'paneer-bhurji');
      expect(entries.single.servingsHalves, 2);
    });

    testWidgets('a log has no day chips and Add is always available',
        (tester) async {
      await pump(tester, host());
      await openAdd(tester, bhurji);

      expect(find.text('Pick at least one day'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(FoodServingSheet.commitKey))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
        'AE4: re-adding a food to a slot that already has it leaves one row '
        'at the new servings', (tester) async {
      await seed(nov(4), bhurji, 2); // today's lunch, 1 katori
      await pump(tester, host(log: await store.readEntries()));
      await openAdd(tester, bhurji);

      await tester.tap(find.bySemanticsLabel('Increase'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Increase'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FoodServingSheet.commitKey));
      await tester.pumpAndSettle();

      final rows = (await storedEntries()).where((e) =>
          e.date == nov(4) &&
          e.slot == MealSlot.lunch &&
          e.foodId == 'paneer-bhurji');
      expect(rows, hasLength(1));
      expect(rows.single.servingsHalves, 4);
    });

    testWidgets('the same food on another day is a separate row',
        (tester) async {
      await seed(nov(3), bhurji, 2);
      await pump(tester, host(log: await store.readEntries()));
      await openAdd(tester, bhurji);
      await tester.tap(find.byKey(FoodServingSheet.commitKey));
      await tester.pumpAndSettle();

      final entries = await storedEntries();
      expect(entries.map((e) => e.date), <LocalDate>[nov(3), nov(4)]);
    });

    testWidgets(
        'committing from the picker closes the sheet and the picker, and the '
        'slot shows the new row', (tester) async {
      await pump(tester, host());
      await tester.tap(find.byKey(DietSlotCard.addFoodKey(MealSlot.breakfast)));
      await tester.pumpAndSettle();
      expect(find.byType(FoodPickerScreen), findsOneWidget);
      expect(find.text('Add to Breakfast, Wed'), findsOneWidget);

      await tester.tap(find.byKey(FoodPickerScreen.rowKey('paneer-bhurji')));
      await tester.pumpAndSettle();
      expect(find.byType(FoodServingSheet), findsOneWidget);
      expect(find.text('Add to Breakfast'), findsOneWidget);

      await tester.tap(find.byKey(FoodServingSheet.commitKey));
      await tester.pumpAndSettle();

      expect(find.byType(FoodServingSheet), findsNothing);
      expect(find.byType(FoodPickerScreen), findsNothing);
      final breakfast = find.byKey(DietSlotCard.cardKey(MealSlot.breakfast));
      expect(
        find.descendant(of: breakfast, matching: find.text('Paneer bhurji')),
        findsOneWidget,
      );
    });

    testWidgets('picker rows are buttons once onPick is wired',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, host());
      await tester.tap(find.byKey(DietSlotCard.addFoodKey(MealSlot.breakfast)));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byKey(FoodPickerScreen.rowKey('paneer'))),
        isSemantics(isButton: true),
      );
      handle.dispose();
    });
  });

  group('edit mode', () {
    Future<void> openEditFromRow(WidgetTester tester) async {
      await tester.tap(find.byKey(DietSlotCard.rowKey(MealSlot.lunch, 'paneer-bhurji')));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a row opens edit mode at its current servings',
        (tester) async {
      await seed(nov(4), bhurji, 3);
      await pump(tester, host(log: await store.readEntries()));
      await openEditFromRow(tester);

      expect(find.byType(FoodServingSheet), findsOneWidget);
      expect(stepperValue('1.5'), findsOneWidget);
      expect(find.text('1.5 katori, 18 g'), findsOneWidget);
      expect(find.text('Repeat on'), findsNothing,
          reason: 'an edit changes that day only');
      expect(
        find.descendant(
            of: find.byType(FilledButton), matching: find.text('Save')),
        findsOneWidget,
      );
      final remove = find.text('Remove from Lunch');
      expect(remove, findsOneWidget);
      expect(tester.widget<Text>(remove).style!.color, AppPalette.danger);
      expect(find.byType(FilledButton), findsOneWidget,
          reason: 'Remove is a text action, not a second filled button');
    });

    testWidgets('Save changes that day only', (tester) async {
      await seed(nov(3), bhurji, 2);
      await seed(nov(4), bhurji, 2);
      await pump(tester, host(log: await store.readEntries()));
      await openEditFromRow(tester);

      await tester.tap(find.bySemanticsLabel('Increase'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FoodServingSheet.commitKey));
      await tester.pumpAndSettle();

      expect(find.byType(FoodServingSheet), findsNothing);
      final entries = await storedEntries();
      expect(entries.singleWhere((e) => e.date == nov(4)).servingsHalves, 3);
      expect(entries.singleWhere((e) => e.date == nov(3)).servingsHalves, 2);
      expect(find.text('18 g'), findsWidgets,
          reason: 'the slot total moves with no refresh');
    });

    testWidgets('Remove then Undo restores the row', (tester) async {
      await seed(nov(4), bhurji, 2);
      await pump(tester, host(log: await store.readEntries()));
      await openEditFromRow(tester);

      await tester.tap(find.byKey(FoodServingSheet.removeKey));
      await tester.pumpAndSettle();
      expect(find.byType(FoodServingSheet), findsNothing);
      expect(find.byKey(DietSlotCard.rowKey(MealSlot.lunch, 'paneer-bhurji')),
          findsNothing);
      expect(find.text('Paneer bhurji removed from Lunch'), findsOneWidget);
      expect(await storedEntries(), isEmpty);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byKey(DietSlotCard.rowKey(MealSlot.lunch, 'paneer-bhurji')),
          findsOneWidget);
      final entries = await storedEntries();
      expect(entries.single.foodId, 'paneer-bhurji');
      expect(entries.single.servingsHalves, 2);
    });

    testWidgets('letting the snackbar expire keeps the row removed',
        (tester) async {
      await seed(nov(4), bhurji, 2);
      await pump(tester, host(log: await store.readEntries()));
      await openEditFromRow(tester);

      await tester.tap(find.byKey(FoodServingSheet.removeKey));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing,
          reason: 'four seconds, then gone: an undo is not a dialog');
      expect(await storedEntries(), isEmpty);
      expect(find.byKey(DietSlotCard.rowKey(MealSlot.lunch, 'paneer-bhurji')),
          findsNothing);
    });

    testWidgets('the undo snackbar is fully visible above the floating bar',
        (tester) async {
      await seed(nov(4), bhurji, 2);
      await pump(tester, host(log: await store.readEntries()));
      await openEditFromRow(tester);

      await tester.tap(find.byKey(FoodServingSheet.removeKey));
      await tester.pumpAndSettle();

      final snack = tester.getRect(find.byType(SnackBar));
      final bar = tester.getRect(find.byType(GlassTabBar));
      final screen = tester.getRect(find.byType(Scaffold).first);
      expect(snack.bottom, lessThanOrEqualTo(bar.top));
      expect(snack.top, greaterThanOrEqualTo(screen.top));
      expect(tester.getRect(find.text('Undo')).bottom,
          lessThanOrEqualTo(bar.top));
    });
  });
}
