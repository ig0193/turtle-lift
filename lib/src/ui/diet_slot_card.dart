import 'package:flutter/material.dart';

import '../data/diet_derived.dart';
import '../data/local_date.dart';
import '../data/meal_slot.dart';
import '../theme/app_palette.dart';
import 'diet_type_glyph.dart';
import 'food_picker_screen.dart';
import 'food_serving_sheet.dart';

/// One meal slot on the selected day (`.slot` in `prototypes/diet.html`).
///
/// A bordered card: the [DietSlotHeader] (name, and the slot total once
/// anything is logged), one row per food, and "+ Add food", which opens the
/// picker for this date and slot. Tapping a row opens the serving sheet in
/// edit mode for that day only. Every figure comes from [DietSlotDay],
/// computed on read.
class DietSlotCard extends StatelessWidget {
  const DietSlotCard({
    required this.slotDay,
    required this.date,
    this.headerSubtitle,
    super.key,
  });

  final DietSlotDay slotDay;

  /// The day "+ Add food" logs into.
  final LocalDate date;

  /// Passed to [DietSlotHeader.subtitle]: the reminder time, shown only when
  /// that slot's reminder is on (A7).
  final String? headerSubtitle;

  static const String addFoodLabel = '+ Add food';

  @visibleForTesting
  static Key cardKey(MealSlot slot) => ValueKey<String>('diet-slot-${slot.name}');

  @visibleForTesting
  static Key totalKey(MealSlot slot) =>
      ValueKey<String>('diet-slot-total-${slot.name}');

  @visibleForTesting
  static Key addFoodKey(MealSlot slot) =>
      ValueKey<String>('diet-slot-add-${slot.name}');

  @visibleForTesting
  static Key rowKey(MealSlot slot, String foodId) =>
      ValueKey<String>('diet-slot-row-${slot.name}-$foodId');

  @override
  Widget build(BuildContext context) {
    final slot = slotDay.slot;
    return Container(
      key: cardKey(slot),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DietSlotHeader(
            slot: slot,
            proteinG: slotDay.isEmpty ? null : slotDay.proteinG,
            subtitle: headerSubtitle,
          ),
          for (final row in slotDay.items)
            _FoodRow(key: rowKey(slot, row.entry.foodId), row: row),
          _AddFoodRow(
            key: addFoodKey(slot),
            slot: slot,
            date: date,
            divided: !slotDay.isEmpty,
          ),
        ],
      ),
    );
  }
}

/// `.sh`: the slot name (with an optional line under it, the reminder time)
/// and, when something is logged, the slot total right-aligned.
class DietSlotHeader extends StatelessWidget {
  const DietSlotHeader({
    required this.slot,
    required this.proteinG,
    this.subtitle,
    super.key,
  });

  final MealSlot slot;

  /// The slot total in whole grams, or null for an empty slot (no total).
  final int? proteinG;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final total = proteinG;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(slot.label, style: _slotNameStyle),
                  if (subtitle != null) Text(subtitle!, style: _metaStyle),
                ],
              ),
            ),
          ),
          if (total != null)
            Text(
              '$total g',
              key: DietSlotCard.totalKey(slot),
              semanticsLabel: '${slot.label}: $total g logged',
              style: _totalStyle,
            ),
        ],
      ),
    );
  }
}

/// `.food`: glyph, name over the servings in words, grams on the right.
/// "Unknown food" (R26) shows no glyph and no servings line, counts 0 g, and
/// still opens the sheet so it can be removed.
class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.row, super.key});

  final DietDayItem row;

  @override
  Widget build(BuildContext context) {
    final food = row.food;
    final serving = food == null ? null : servingPhrase(food, row.servings);
    final grams = '${formatGramsShort(row.proteinG)} g';
    return Semantics(
      container: true,
      button: true,
      label: <String>[row.name, ?serving, grams].join(', '),
      excludeSemantics: true,
      onTap: () => showEditFoodSheet(context, row: row),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showEditFoodSheet(context, row: row),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppPalette.border)),
          ),
          child: Row(
            children: <Widget>[
              if (food != null) ...<Widget>[
                DietTypeGlyph(food.dietType),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(row.name, style: _nameStyle),
                    if (serving != null) ...<Widget>[
                      const SizedBox(height: 1),
                      Text(serving, style: _metaStyle),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(grams, style: _rowGramsStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.addfood`: a full-width text row that opens the picker for this slot.
class _AddFoodRow extends StatelessWidget {
  const _AddFoodRow({
    required this.slot,
    required this.date,
    required this.divided,
    super.key,
  });

  final MealSlot slot;
  final LocalDate date;

  /// A rule above it when rows sit above; an empty slot has none.
  final bool divided;

  @override
  Widget build(BuildContext context) {
    void open() => pushFoodPicker(context, date: date, slot: slot);
    return Semantics(
      container: true,
      button: true,
      label: 'Add food to ${slot.label}',
      excludeSemantics: true,
      onTap: open,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          alignment: Alignment.centerLeft,
          decoration: divided
              ? const BoxDecoration(
                  border: Border(top: BorderSide(color: AppPalette.border)),
                )
              : null,
          child: const Text(DietSlotCard.addFoodLabel, style: _addStyle),
        ),
      ),
    );
  }
}

const TextStyle _slotNameStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: AppPalette.textPrimary,
);

const TextStyle _totalStyle = TextStyle(
  fontSize: 15,
  color: AppPalette.textPrimary,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

const TextStyle _nameStyle = TextStyle(
  fontSize: 15,
  color: AppPalette.textPrimary,
);

const TextStyle _metaStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textMuted,
);

const TextStyle _rowGramsStyle = TextStyle(
  fontSize: 13,
  color: AppPalette.textSecondary,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

const TextStyle _addStyle = TextStyle(
  fontSize: 13,
  color: AppPalette.textSecondary,
);
