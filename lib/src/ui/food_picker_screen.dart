import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/food.dart';
import '../data/food_index.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'diet_type_glyph.dart';
import 'food_serving_sheet.dart';
import 'ghost_button.dart';
import 'muscle_search_field.dart';

/// Short weekday names, 0 = Monday (KTD5's weekday numbering).
const List<String> kDietWeekdayShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Protein per serving as the food list holds it: one decimal (R7).
String formatProteinGrams(double grams) => grams.toStringAsFixed(1);

/// Which diet chip the picker shows. **In memory for the run only** (A15):
/// it survives closing and reopening the picker, and a cold start or the
/// reboot after Delete all data resets it to All. Never stored.
class FoodPickerFilter extends Notifier<DietFilter> {
  @override
  DietFilter build() => DietFilter.all;

  void select(DietFilter filter) => state = filter;
}

final foodPickerFilterProvider =
    NotifierProvider<FoodPickerFilter, DietFilter>(FoodPickerFilter.new);

/// Pushes the picker for [slot] on [weekday] (0 = Monday).
///
/// Tapping a food opens the serving sheet over the picker; committing Add
/// closes the sheet and then the picker, back to the Diet pane with the new
/// row in its slot (U11). Backing out of the sheet leaves the picker open.
Future<void> pushFoodPicker(
  BuildContext context, {
  required int weekday,
  required MealSlot slot,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pickerContext) => FoodPickerScreen(
          weekday: weekday,
          slot: slot,
          onPick: (food) async {
            final added = await showAddFoodSheet(
              pickerContext,
              food: food,
              weekday: weekday,
              slot: slot,
            );
            if (added && pickerContext.mounted) {
              Navigator.of(pickerContext).pop();
            }
          },
        ),
      ),
    );

/// Find a food for one meal slot on one day in a few taps (`addFood()` in
/// `prototypes/diet.html`).
///
/// A search field, then four outlined single-select chips, then every food the
/// chip admits whose name or alias matches, highest protein per serving first
/// ([FoodIndex.search], A15).
///
/// **Rows are tappable only when [onPick] is given.** [pushFoodPicker] passes
/// one that opens the serving sheet; without it the rows are plain read-only
/// rows rather than buttons that do nothing.
class FoodPickerScreen extends ConsumerStatefulWidget {
  const FoodPickerScreen({
    required this.weekday,
    required this.slot,
    this.onPick,
    super.key,
  });

  /// 0 = Monday to 6 = Sunday.
  final int weekday;
  final MealSlot slot;

  /// Called with the tapped food. Null leaves rows untappable.
  final ValueChanged<Food>? onPick;

  /// "Add to Lunch, Wed".
  static String titleFor(int weekday, MealSlot slot) =>
      'Add to ${slot.label}, ${kDietWeekdayShort[weekday]}';

  static const String searchHint = 'Search foods';
  static const String noMatchCopy = 'No foods match';
  static const String clearSearchLabel = 'Clear search';

  /// The Egg chip means veg plus egg (A1); the caption says so.
  static const String eggCaption = 'Veg and egg foods';
  static const String sortCaption = 'Protein per serving, highest first';

  @visibleForTesting
  static const Key searchKey = ValueKey<String>('food-picker-search');

  @visibleForTesting
  static const Key clearSearchKey = ValueKey<String>('food-picker-clear');

  @visibleForTesting
  static Key chipKey(DietFilter filter) =>
      ValueKey<String>('food-picker-chip-${filter.name}');

  @visibleForTesting
  static Key rowKey(String foodId) =>
      ValueKey<String>('food-picker-row-$foodId');

  @override
  ConsumerState<FoodPickerScreen> createState() => _FoodPickerScreenState();
}

class _FoodPickerScreenState extends ConsumerState<FoodPickerScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(foodPickerFilterProvider);
    final foods = ref.watch(foodIndexProvider).search(_query, filter);

    return AppScreen.pushed(
      title: FoodPickerScreen.titleFor(widget.weekday, widget.slot),
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 4),
          MuscleSearchField.editable(
            key: FoodPickerScreen.searchKey,
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            // The list is the content: a user browsing by chip should not
            // have a keyboard covering half of it.
            autofocus: false,
            hint: FoodPickerScreen.searchHint,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final f in DietFilter.values)
                _FilterChip(
                  key: FoodPickerScreen.chipKey(f),
                  filter: f,
                  selected: f == filter,
                  onTap: () =>
                      ref.read(foodPickerFilterProvider.notifier).select(f),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            filter == DietFilter.egg
                ? '${FoodPickerScreen.eggCaption} · protein per serving, '
                    'highest first'
                : FoodPickerScreen.sortCaption,
            style: _captionStyle,
          ),
          const SizedBox(height: 4),
          if (foods.isEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const Text(FoodPickerScreen.noMatchCopy, style: _noMatchStyle),
            if (_query.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              GhostButton(
                buttonKey: FoodPickerScreen.clearSearchKey,
                label: FoodPickerScreen.clearSearchLabel,
                onTap: _clearSearch,
              ),
            ],
          ] else
            for (final food in foods)
              _FoodRow(
                key: FoodPickerScreen.rowKey(food.id),
                food: food,
                onTap: widget.onPick == null
                    ? null
                    : () => widget.onPick!(food),
              ),
        ],
      ),
    );
  }
}

/// The chip's word for each filter. "Non-veg" matches [DietType.label].
String _filterLabel(DietFilter filter) => switch (filter) {
      DietFilter.all => 'All',
      DietFilter.veg => DietType.veg.label,
      DietFilter.egg => DietType.egg.label,
      DietFilter.nonVeg => DietType.nonVeg.label,
    };

DietType? _filterType(DietFilter filter) => switch (filter) {
      DietFilter.all => null,
      DietFilter.veg => DietType.veg,
      DietFilter.egg => DietType.egg,
      DietFilter.nonVeg => DietType.nonVeg,
    };

/// `.chip` in `prototypes/diet.html`: outlined, the selected one in the
/// accent with a raised neutral behind it, the same selection language as
/// `_GenderChip` in `personal_details_screen.dart`. Never filled.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final DietFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _filterLabel(filter);
    final type = _filterType(filter);
    final color = selected ? AppPalette.accentStrong : AppPalette.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppPalette.mutedSurface : null,
            border: Border.all(
              color: selected ? AppPalette.accentStrong : AppPalette.border,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (type != null) ...<Widget>[
                DietTypeGlyph(type, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.frow`: glyph, name over "Veg · serving", protein per serving on the
/// right. The serving label already carries its grams ("5 cubes, 50 g"), so
/// the grams are not repeated.
class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.onTap, super.key});

  final Food food;

  /// Null: a read-only row, not announced as a button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final protein = formatProteinGrams(food.proteinPerServingG);
    final meta = '${food.dietType.label} · ${food.servingLabel}';
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        children: <Widget>[
          DietTypeGlyph(food.dietType),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(food.name, style: _nameStyle),
                const SizedBox(height: 2),
                Text(meta, style: _captionStyle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(protein, style: _proteinStyle),
          const Text(' g', style: _captionStyle),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '${food.name}. $meta. $protein g protein per serving',
      excludeSemantics: true,
      child: onTap == null
          ? row
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: row,
            ),
    );
  }
}

const TextStyle _captionStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textMuted,
);

const TextStyle _noMatchStyle = TextStyle(
  fontSize: 15,
  color: AppPalette.textSecondary,
);

const TextStyle _nameStyle = TextStyle(
  fontSize: 15,
  color: AppPalette.textPrimary,
);

const TextStyle _proteinStyle = TextStyle(
  fontSize: 17,
  color: AppPalette.textPrimary,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);
