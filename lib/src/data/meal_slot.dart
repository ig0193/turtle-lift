/// The four meal slots of a Diet day, in the order a day runs.
///
/// **Stored by [name], never by index** -- `diet_plan_items.slot` and
/// `meal_ticks.slot` hold `breakfast`, `lunch`, `snack` or `dinner`, and a CHECK
/// on both tables admits only those four. Reordering this enum must not move a
/// user's meals, and a fifth slot is a schema step, not a new value here.
enum MealSlot {
  breakfast('Breakfast'),
  lunch('Lunch'),
  snack('Snack'),
  dinner('Dinner');

  const MealSlot(this.label);

  /// Sentence-case display label.
  final String label;
}
