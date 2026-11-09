import 'package:flutter/material.dart';

import '../data/diet_derived.dart';
import '../data/meal_slot.dart';
import '../theme/app_palette.dart';
import 'diet_type_glyph.dart';
import 'food_picker_screen.dart';
import 'food_serving_sheet.dart';

/// One meal slot on the selected day (`.slot` in `prototypes/diet.html`).
///
/// A bordered card: the [DietSlotHeader] (name, and the slot total once
/// anything is planned), one row per food, and "+ Add food", which opens the
/// picker for this weekday and slot. Tapping a row opens the serving sheet in
/// edit mode for that weekday only (U11). Every figure comes from
/// [DietSlotDay], computed on read.
class DietSlotCard extends StatelessWidget {
  const DietSlotCard({
    required this.slotDay,
    required this.weekday,
    this.headerTrailing,
    this.headerSubtitle,
    super.key,
  });

  final DietSlotDay slotDay;

  /// 0 = Monday to 6 = Sunday: the day "+ Add food" plans into.
  final int weekday;

  /// Passed to [DietSlotHeader.trailing]: the [DietEatenTick], only where
  /// [DietSlotDay.canTick] (R18).
  final Widget? headerTrailing;

  /// Passed to [DietSlotHeader.subtitle]: the reminder time, shown only when
  /// that slot's reminder is on (U17, A7).
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

  /// The slot's eaten tick, when it has one.
  static Key tickKey(MealSlot slot) =>
      ValueKey<String>('diet-slot-tick-${slot.name}');

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
            trailing: headerTrailing,
          ),
          for (final row in slotDay.items)
            _FoodRow(key: rowKey(slot, row.item.foodId), row: row),
          _AddFoodRow(
            key: addFoodKey(slot),
            slot: slot,
            weekday: weekday,
            divided: !slotDay.isEmpty,
          ),
        ],
      ),
    );
  }
}

/// `.sh`: the slot name (with an optional line under it) and, when something
/// is planned, the slot total right-aligned, then an optional trailing
/// control.
///
/// **Public because two later units hang things on it**: the eaten tick
/// goes in [trailing] (U14) and the reminder time in [subtitle] (U17).
class DietSlotHeader extends StatelessWidget {
  const DietSlotHeader({
    required this.slot,
    required this.proteinG,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final MealSlot slot;

  /// The slot total in whole grams, or null for an empty slot (no total).
  final int? proteinG;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final total = proteinG;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      // A trailing control brings its own 48pt box, so the header gives up
      // the padding that box already provides rather than growing past it.
      padding: trailing == null
          ? const EdgeInsets.fromLTRB(12, 12, 12, 8)
          : const EdgeInsets.fromLTRB(12, 0, 4, 0),
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
              semanticsLabel: '${slot.label}: $total g planned',
              style: _totalStyle,
            ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 2),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// `.tickbtn`: one tap marks a slot eaten on its date (R18, KD2).
///
/// **Outlined, never filled**, like every selection control in the app: off
/// is a quiet [AppPalette.border] ring with no glyph; on is an
/// [AppPalette.accentStrong] ring and check. The accent is the eaten colour
/// on Diet (KTD20), the same one the eaten layer of the day bar uses.
///
/// A 32pt ring in a 48pt tap target. The semantics name the slot and the
/// state ("Lunch eaten", "Lunch not eaten"), so a screen reader hears what a
/// tap will change without relying on the ring's colour.
class DietEatenTick extends StatelessWidget {
  const DietEatenTick({
    required this.slot,
    required this.ticked,
    required this.onTap,
    super.key,
  });

  final MealSlot slot;
  final bool ticked;
  final VoidCallback onTap;

  @visibleForTesting
  static const Key ringKey = ValueKey<String>('diet-eaten-tick-ring');

  /// "Lunch eaten" / "Lunch not eaten".
  static String labelFor(MealSlot slot, {required bool ticked}) =>
      '${slot.label} ${ticked ? 'eaten' : 'not eaten'}';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      checked: ticked,
      label: labelFor(slot, ticked: ticked),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Container(
              key: ringKey,
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 1.5,
                  color: ticked ? AppPalette.accentStrong : AppPalette.border,
                ),
              ),
              child: ticked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppPalette.accentStrong,
                    )
                  : null,
            ),
          ),
        ),
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
    required this.weekday,
    required this.divided,
    super.key,
  });

  final MealSlot slot;
  final int weekday;

  /// A rule above it when rows sit above; an empty slot has none.
  final bool divided;

  @override
  Widget build(BuildContext context) {
    void open() => pushFoodPicker(context, weekday: weekday, slot: slot);
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
