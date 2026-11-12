import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/food.dart';
import 'package:turtle_lift/src/data/food_index.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/diet_type_glyph.dart';
import 'package:turtle_lift/src/ui/food_picker_screen.dart';
import 'package:turtle_lift/src/ui/ghost_button.dart';

/// The food picker, on fixture foods (the shipped list is still under owner
/// review, so no test pins its values).
void main() {
  Map<String, Object?> food(
    String id,
    String name,
    String dietType,
    double protein, {
    List<String> aliases = const <String>[],
    String serving = '1 katori cooked, 30 g dry',
    int grams = 30,
  }) =>
      <String, Object?>{
        'id': id,
        'name': name,
        'aliases': aliases,
        'dietType': dietType,
        'servingLabel': serving,
        'gramsPerServing': grams,
        'proteinPerServingG': protein,
        'proteinPer100g': protein,
        'ifctCode': 'X001',
        'reviewedBy': 'pending-owner-review',
      };

  final foods = FoodIndex.fromJson(<Map<String, Object?>>[
    food('chana-dal', 'Chana dal', 'veg', 6.5),
    food('kala-chana', 'Kala chana', 'veg', 7.1, aliases: ['desi chana']),
    food('paneer', 'Paneer', 'veg', 9.4, serving: '5 cubes, 50 g', grams: 50),
    food('boiled-egg', 'Boiled egg', 'egg', 6.3,
        serving: '1 boiled egg, 50 g', grams: 50),
    food('chicken-breast', 'Chicken breast', 'nonVeg', 23.0,
        serving: '1 piece, 100 g raw', grams: 100),
  ]);

  Widget host({Widget? home}) => ProviderScope(
        overrides: [foodIndexProvider.overrideWithValue(foods)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: home ??
              const FoodPickerScreen(weekday: 2, slot: MealSlot.lunch),
        ),
      );

  Finder row(String id) => find.byKey(FoodPickerScreen.rowKey(id));

  Future<void> pumpPicker(WidgetTester tester, {Widget? home}) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('the title names the slot and weekday passed in',
      (tester) async {
    await pumpPicker(tester);
    expect(find.text('Add to Lunch, Wed'), findsOneWidget);
    expect(FoodPickerScreen.titleFor(6, MealSlot.breakfast),
        'Add to Breakfast, Sun');
  });

  testWidgets('lists every food, highest protein first (A15)', (tester) async {
    await pumpPicker(tester);
    final ids = <String>[
      'chicken-breast',
      'paneer',
      'kala-chana',
      'chana-dal',
      'boiled-egg',
    ];
    for (final id in ids) {
      expect(row(id), findsOneWidget);
    }
    final ys = [for (final id in ids) tester.getTopLeft(row(id)).dy];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]));
    }
  });

  testWidgets(
      'a row shows the name, the type word, the serving and protein per '
      'serving in tabular figures', (tester) async {
    await pumpPicker(tester);

    final paneer = row('paneer');
    expect(find.descendant(of: paneer, matching: find.text('Paneer')),
        findsOneWidget);
    expect(
      find.descendant(of: paneer, matching: find.text('Veg · 5 cubes, 50 g')),
      findsOneWidget,
    );
    final grams = find.descendant(of: paneer, matching: find.text('9.4'));
    expect(grams, findsOneWidget);
    expect(
      tester.widget<Text>(grams).style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('typing "chana" narrows to chana foods; clearing restores all',
      (tester) async {
    await pumpPicker(tester);

    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), 'chana');
    await tester.pumpAndSettle();
    expect(row('chana-dal'), findsOneWidget);
    expect(row('kala-chana'), findsOneWidget);
    expect(row('paneer'), findsNothing);
    expect(row('chicken-breast'), findsNothing);

    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), '');
    await tester.pumpAndSettle();
    expect(row('paneer'), findsOneWidget);
    expect(row('chicken-breast'), findsOneWidget);
  });

  testWidgets('no match shows "No foods match" and a ghost Clear search',
      (tester) async {
    await pumpPicker(tester);

    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(FoodPickerScreen.noMatchCopy), findsOneWidget);
    expect(FoodPickerScreen.noMatchCopy, 'No foods match');
    expect(
      find.descendant(
          of: find.byType(GhostButton), matching: find.text('Clear search')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(FoodPickerScreen.clearSearchKey));
    await tester.pumpAndSettle();
    expect(find.text(FoodPickerScreen.noMatchCopy), findsNothing);
    expect(row('paneer'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.descendant(
              of: find.byKey(FoodPickerScreen.searchKey),
              matching: find.byType(TextField)))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('typing again after a no-match search narrows to the new query',
      (tester) async {
    await pumpPicker(tester);
    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), 'zzz');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), 'paneer');
    await tester.pumpAndSettle();
    expect(row('paneer'), findsOneWidget);
    expect(row('chicken-breast'), findsNothing);
  });

  testWidgets('the Egg chip shows veg and egg foods, with its caption (A1)',
      (tester) async {
    await pumpPicker(tester);
    expect(find.textContaining(FoodPickerScreen.eggCaption), findsNothing);

    await tester.tap(find.byKey(FoodPickerScreen.chipKey(DietFilter.egg)));
    await tester.pumpAndSettle();

    expect(row('boiled-egg'), findsOneWidget);
    expect(row('paneer'), findsOneWidget);
    expect(row('chicken-breast'), findsNothing);
    expect(find.textContaining(FoodPickerScreen.eggCaption), findsOneWidget);
    expect(FoodPickerScreen.eggCaption, 'Veg and egg foods');
  });

  testWidgets('Veg and Non-veg chips admit only their own type',
      (tester) async {
    await pumpPicker(tester);

    await tester.tap(find.byKey(FoodPickerScreen.chipKey(DietFilter.veg)));
    await tester.pumpAndSettle();
    expect(row('boiled-egg'), findsNothing);
    expect(row('chicken-breast'), findsNothing);
    expect(row('paneer'), findsOneWidget);

    await tester.tap(find.byKey(FoodPickerScreen.chipKey(DietFilter.nonVeg)));
    await tester.pumpAndSettle();
    expect(row('chicken-breast'), findsOneWidget);
    expect(row('paneer'), findsNothing);
  });

  testWidgets('chips are single-select and announce their state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPicker(tester);

    expect(
      tester.getSemantics(find.byKey(FoodPickerScreen.chipKey(DietFilter.all))),
      isSemantics(label: 'All', isButton: true, isSelected: true),
    );
    await tester.tap(find.byKey(FoodPickerScreen.chipKey(DietFilter.veg)));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(FoodPickerScreen.chipKey(DietFilter.all))),
      isSemantics(label: 'All', isButton: true, isSelected: false),
    );
    expect(
      tester.getSemantics(find.byKey(FoodPickerScreen.chipKey(DietFilter.veg))),
      isSemantics(label: 'Veg', isButton: true, isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('every chip is a 48pt tap target (taste pass)', (tester) async {
    await pumpPicker(tester);
    for (final filter in DietFilter.values) {
      expect(tester.getSize(find.byKey(FoodPickerScreen.chipKey(filter))).height,
          greaterThanOrEqualTo(48),
          reason: '$filter');
    }
  });

  testWidgets('the chip choice survives popping and reopening in the run',
      (tester) async {
    await pumpPicker(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                pushFoodPicker(context, weekday: 2, slot: MealSlot.lunch),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FoodPickerScreen.chipKey(DietFilter.nonVeg)));
    await tester.pumpAndSettle();
    expect(row('paneer'), findsNothing);

    Navigator.of(tester.element(find.byType(FoodPickerScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(FoodPickerScreen), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(row('paneer'), findsNothing);
    expect(row('chicken-breast'), findsOneWidget);
  });

  testWidgets('every diet-type glyph has its word beside it', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPicker(tester);

    for (final (id, word) in <(String, String)>[
      ('paneer', 'Veg'),
      ('boiled-egg', 'Egg'),
      ('chicken-breast', 'Non-veg'),
    ]) {
      final glyph = find.descendant(
          of: row(id), matching: find.byType(DietTypeGlyph));
      expect(glyph, findsOneWidget);
      expect(tester.widget<DietTypeGlyph>(glyph).type.label, word);
      expect(
        find.descendant(of: row(id), matching: find.textContaining(word)),
        findsWidgets,
        reason: 'the shape never stands alone',
      );
      expect(tester.getSemantics(row(id)).label, contains(word));
    }
    // The chips pair glyph and word too.
    for (final f in <DietFilter>[DietFilter.veg, DietFilter.egg, DietFilter.nonVeg]) {
      expect(
        find.descendant(
            of: find.byKey(FoodPickerScreen.chipKey(f)),
            matching: find.byType(DietTypeGlyph)),
        findsOneWidget,
      );
    }
    handle.dispose();
  });

  testWidgets('without a pick handler rows are not buttons (nothing inert)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPicker(tester);

    expect(
      tester.getSemantics(row('paneer')),
      isNot(isSemantics(isButton: true)),
    );
    handle.dispose();
  });

  testWidgets('with a pick handler, tapping a row hands it the food',
      (tester) async {
    Food? picked;
    await pumpPicker(
      tester,
      home: FoodPickerScreen(
        weekday: 2,
        slot: MealSlot.lunch,
        onPick: (food) => picked = food,
      ),
    );

    await tester.tap(row('paneer'));
    await tester.pumpAndSettle();
    expect(picked?.id, 'paneer');
  });

  testWidgets('no text under 12pt', (tester) async {
    await pumpPicker(tester);
    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), 'zzz');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(FoodPickerScreen.searchKey), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FoodPickerScreen.chipKey(DietFilter.egg)));
    await tester.pumpAndSettle();

    final sizes = <double>[];
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      p.text.visitChildren((span) {
        final size = span.style?.fontSize;
        if (size != null) sizes.add(size);
        return true;
      });
    }
    expect(sizes, isNotEmpty);
    expect(sizes.where((s) => s < 12), isEmpty);
  });
}
