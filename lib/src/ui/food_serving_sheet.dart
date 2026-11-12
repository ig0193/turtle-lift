import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diet_derived.dart';
import '../data/diet_plan.dart';
import '../data/diet_plan_store.dart';
import '../data/food.dart';
import '../data/serving_phrase.dart';
import '../data/training_plan.dart' show kWeekdayCount;
import '../theme/app_palette.dart';
import 'diet_type_glyph.dart';
import 'food_picker_screen.dart' show formatProteinGrams;
import 'stepper_field.dart';
import 'week_day_chip.dart';

// The phrasing moved to the data layer so diet reminders (U17) can share it;
// re-exported so the sheet stays the one import for its callers.
export '../data/serving_phrase.dart' show formatGramsShort, servingPhrase;

/// Opens the serving sheet in add mode for [food] into [slot], with [weekday]
/// preselected under Repeat on. Completes true once the food is written, so
/// the picker underneath can close too (U11 approach 3).
Future<bool> showAddFoodSheet(
  BuildContext context, {
  required Food food,
  required int weekday,
  required MealSlot slot,
}) async {
  final added = await _showSheet<bool>(
    context,
    FoodServingSheet.add(food: food, weekday: weekday, slot: slot),
  );
  return added ?? false;
}

/// Opens the serving sheet in edit mode for one row on its own weekday.
///
/// **Remove pops the sheet first, then writes, then offers Undo** from the
/// [ScaffoldMessenger] above [context] -- the shell's, so the snackbar sits
/// above the floating tab bar (A13: four seconds, no confirmation dialog).
/// Undo calls `restoreItem`; if the remove was this week's first edit, the
/// copied version stays, identical to its source and harmless.
Future<void> showEditFoodSheet(
  BuildContext context, {
  required DietDayItem row,
}) async {
  // Read before the await: the slot card that opened the sheet may be gone
  // (the row is removed) by the time Undo is tapped.
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final result = await _showSheet<_EditResult>(
    context,
    FoodServingSheet.edit(row: row),
  );
  if (result != _EditResult.remove) return;

  final log = container.read(dietPlanLogProvider.notifier);
  final removed = await log.removeItem(row.item);
  if (removed == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${row.name} removed from ${row.item.slot.label}'),
        duration: FoodServingSheet.undoDuration,
        // A snackbar with an action persists by default; this one is an undo
        // window, not a question, so it times out.
        persist: false,
        action: SnackBarAction(
          label: FoodServingSheet.undoLabel,
          // The snackbar is inverse (light) surface; the content text and the
          // action read in the same dark role, the action set apart by weight.
          textColor: AppPalette.pageBackground,
          onPressed: () => log.restoreItem(removed),
        ),
      ),
    );
}

/// The sheet shape of `schedule_pane.dart`'s explain sheet: surface colour,
/// 18pt top corners, content sized to fit.
Future<T?> _showSheet<T>(BuildContext context, Widget sheet) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => sheet,
    );

enum _EditResult { remove }

/// Servings for one food in one slot (`.sheet` in `prototypes/diet.html`).
///
/// **Add**: a stepper from 0.5 to 4 in halves with the live protein beneath,
/// seven outlined Repeat on chips (the opening day preselected) and a filled
/// "Add to Lunch" that is disabled, with the reason beside it, while no day
/// is picked. One commit writes every picked day; a food already in that slot
/// on a picked day has its servings replaced, never duplicated (R14, AE4).
///
/// **Edit** (a tapped slot-card row, that weekday only): the stepper, a filled
/// Save, and "Remove from Lunch" as text in the danger role. An unknown food
/// (R26) has nothing to scale, so it offers Remove alone.
///
/// Servings are stored as halves (KTD6); this widget holds halves too, so no
/// float ever reaches the store.
class FoodServingSheet extends ConsumerStatefulWidget {
  const FoodServingSheet.add({
    required Food this.food,
    required this.weekday,
    required this.slot,
    super.key,
  }) : row = null;

  FoodServingSheet.edit({required DietDayItem this.row, super.key})
      : food = row.food,
        weekday = row.item.weekday,
        slot = row.item.slot;

  /// Null only in edit mode on an unknown food.
  final Food? food;
  final int weekday;
  final MealSlot slot;

  /// The row being edited; null in add mode.
  final DietDayItem? row;

  bool get isEdit => row != null;

  static const String repeatOnLabel = 'Repeat on';
  static const String pickADayHint = 'Pick at least one day';
  static const String saveLabel = 'Save';
  static const String undoLabel = 'Undo';
  static const String unknownFoodCopy = 'This food is no longer in the list.';
  static const Duration undoDuration = Duration(seconds: 4);

  static String addLabel(MealSlot slot) => 'Add to ${slot.label}';
  static String removeLabel(MealSlot slot) => 'Remove from ${slot.label}';

  @visibleForTesting
  static const Key commitKey = ValueKey<String>('serving-sheet-commit');

  @visibleForTesting
  static const Key removeKey = ValueKey<String>('serving-sheet-remove');

  @visibleForTesting
  static Key repeatChipKey(int weekday) =>
      ValueKey<String>('serving-sheet-day-$weekday');

  @override
  ConsumerState<FoodServingSheet> createState() => _FoodServingSheetState();
}

class _FoodServingSheetState extends ConsumerState<FoodServingSheet> {
  late int _halves = widget.row?.item.servingsHalves ?? 2;
  late final Set<int> _days = <int>{widget.weekday};
  bool _busy = false;

  double get _servings => _halves / 2;

  void _onServings(double? value) {
    if (value == null) return;
    setState(() => _halves =
        (value * 2).round().clamp(kMinServingsHalves, kMaxServingsHalves));
  }

  void _toggleDay(int weekday) => setState(() {
        if (!_days.add(weekday)) _days.remove(weekday);
      });

  Future<void> _commit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final log = ref.read(dietPlanLogProvider.notifier);
    final row = widget.row;
    if (row == null) {
      await log.addFood(
        weekdays: Set<int>.of(_days),
        slot: widget.slot,
        foodId: widget.food!.id,
        halves: _halves,
      );
      if (mounted) Navigator.of(context).pop(true);
    } else {
      if (_halves != row.item.servingsHalves) {
        await log.setServings(row.item, _halves);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final canAdd = widget.isEdit || _days.isNotEmpty;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Heading(food: food),
            if (food != null) ...<Widget>[
              const SizedBox(height: 14),
              _ServingStepper(
                food: food,
                servings: _servings,
                onChanged: _onServings,
              ),
            ],
            if (!widget.isEdit) ...<Widget>[
              const SizedBox(height: 16),
              const Text(FoodServingSheet.repeatOnLabel, style: _labelStyle),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (var d = 0; d < kWeekdayCount; d++)
                    WeekDayChip(
                      key: FoodServingSheet.repeatChipKey(d),
                      weekday: d,
                      selected: _days.contains(d),
                      onTap: () => _toggleDay(d),
                    ),
                ],
              ),
              if (!canAdd)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(FoodServingSheet.pickADayHint, style: _hintStyle),
                ),
            ],
            if (food != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton(
                key: FoodServingSheet.commitKey,
                onPressed: canAdd && !_busy ? _commit : null,
                child: Text(widget.isEdit
                    ? FoodServingSheet.saveLabel
                    : FoodServingSheet.addLabel(widget.slot)),
              ),
            ],
            if (widget.isEdit)
              _DangerTextButton(
                key: FoodServingSheet.removeKey,
                label: FoodServingSheet.removeLabel(widget.slot),
                onTap: () => Navigator.of(context).pop(_EditResult.remove),
              ),
          ],
        ),
      ),
    );
  }
}

/// The diet-type glyph, the food's name, and what one serving is.
class _Heading extends StatelessWidget {
  const _Heading({required this.food});

  final Food? food;

  @override
  Widget build(BuildContext context) {
    final f = food;
    final meta = f == null
        ? FoodServingSheet.unknownFoodCopy
        : '${f.dietType.label} · ${f.servingLabel} · '
            '${formatProteinGrams(f.proteinPerServingG)} g protein';
    return Row(
      children: <Widget>[
        if (f != null) ...<Widget>[
          DietTypeGlyph(f.dietType),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(f?.name ?? kUnknownFoodName, style: _titleStyle),
              const SizedBox(height: 2),
              Text(meta, style: _hintStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// `.stepper`: the shared [StepperField] bounded to 0.5..4, with the servings
/// in words and the protein they carry underneath, updated live.
class _ServingStepper extends StatelessWidget {
  const _ServingStepper({
    required this.food,
    required this.servings,
    required this.onChanged,
  });

  final Food food;
  final double servings;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final protein = proteinUnitsFor(food, (servings * 2).round()) /
        kProteinUnitsPerGram;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      decoration: BoxDecoration(
        color: AppPalette.mutedSurface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          StepperField(
            value: servings,
            step: 0.5,
            decimals: 1,
            min: kMinServingsHalves / 2,
            max: kMaxServingsHalves / 2,
            semanticsLabel: 'Servings',
            onChanged: onChanged,
          ),
          Text(
            '${servingPhrase(food, servings)}, ${formatGramsShort(protein)} g',
            textAlign: TextAlign.center,
            style: _liveStyle,
          ),
        ],
      ),
    );
  }
}

/// `.textbtn.danger`: a 48pt text action in the danger role. Not a second
/// filled or bordered button; the sheet's one primary action is Save.
class _DangerTextButton extends StatelessWidget {
  const _DangerTextButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.only(top: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppPalette.danger,
            ),
          ),
        ),
      ),
    );
  }
}

const TextStyle _titleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  color: AppPalette.textPrimary,
);

const TextStyle _labelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: AppPalette.textSecondary,
);

const TextStyle _hintStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textMuted,
);

const TextStyle _liveStyle = TextStyle(
  fontSize: 13,
  color: AppPalette.textSecondary,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);
