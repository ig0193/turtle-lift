import 'package:flutter/material.dart';

import '../data/load_type.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'stepper_field.dart';

/// One set, in whichever shape its load type calls for.
///
/// **One widget for all four types, not four widgets.** The completion rule,
/// the prefill rendering and the delete gesture are identical across them; only
/// which fields appear differs. Four row widgets would be four places for the
/// assisted inversion or the completion rule to drift.
///
/// | type | row |
/// |---|---|
/// | `weighted` | `[kg] × [reps] ✓` |
/// | `bodyweight` | `[reps]` plus a collapsed add-weight chip |
/// | `assisted` | `[kg] assist × [reps] ✓` |
/// | `timed` | `[m:ss]` plus quick-fills and a collapsed add-weight chip |
class SetRow extends StatefulWidget {
  const SetRow({
    required this.index,
    required this.loadType,
    required this.entry,
    required this.isPrefill,
    required this.onChanged,
    required this.onToggleComplete,
    required this.onDelete,
    super.key,
  });

  /// Zero-based position, rendered one-based as the set number.
  final int index;

  final LoadType loadType;

  /// The values currently on the row, prefilled or entered.
  final SetEntry entry;

  /// Whether these values are still a guess carried from the last session.
  final bool isPrefill;

  final ValueChanged<SetEntry> onChanged;

  /// Asked to complete the set. The row refuses and focuses the required field
  /// when that field is empty, so this fires only when it is a real request.
  final VoidCallback onToggleComplete;

  final VoidCallback onDelete;

  /// The key a test taps to tick set [index].
  static Key checkKey(int index) => ValueKey<String>('set-check-$index');

  /// The key a test finds the whole row by.
  static Key rowKey(int index) => ValueKey<String>('set-row-$index');

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  final FocusNode _requiredFieldFocus = FocusNode();
  late bool _weightExpanded = _hasOptionalWeight;

  bool get _hasOptionalWeight =>
      (widget.entry.addedKg ?? 0) > 0 || (widget.entry.weightKg ?? 0) > 0;

  @override
  void dispose() {
    _requiredFieldFocus.dispose();
    super.dispose();
  }

  void _emit(SetEntry next) => widget.onChanged(next);

  /// Marks an argument as "not being changed", so that passing null really
  /// clears a field.
  ///
  /// A plain `value ?? existing` cannot express the difference, which would
  /// mean a user who clears the weight field watches the old number come
  /// straight back — and then a set they meant to empty completes with a value
  /// they deleted.
  static const Object _unchanged = Object();

  SetEntry _copy({
    Object? weightKg = _unchanged,
    Object? reps = _unchanged,
    Object? addedKg = _unchanged,
    Object? assistKg = _unchanged,
    Object? durationSec = _unchanged,
  }) =>
      SetEntry(
        id: widget.entry.id,
        position: widget.entry.position,
        completed: widget.entry.completed,
        weightKg: identical(weightKg, _unchanged)
            ? widget.entry.weightKg
            : weightKg as double?,
        reps: identical(reps, _unchanged) ? widget.entry.reps : reps as int?,
        addedKg: identical(addedKg, _unchanged)
            ? widget.entry.addedKg
            : addedKg as double?,
        assistKg: identical(assistKg, _unchanged)
            ? widget.entry.assistKg
            : assistKg as double?,
        durationSec: identical(durationSec, _unchanged)
            ? widget.entry.durationSec
            : durationSec as int?,
      );

  /// Tapping the checkmark on an empty required field focuses that field
  /// instead of completing the set.
  void _requestComplete() {
    if (!hasRequiredValue(widget.loadType, widget.entry) &&
        !widget.entry.completed) {
      _requiredFieldFocus.requestFocus();
      return;
    }
    widget.onToggleComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey<String>('dismiss-${widget.entry.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: const ColoredBox(color: AppPalette.danger),
      child: GestureDetector(
        // The second way to delete, so removing a set never depends on a swipe
        // the user cannot make one-handed.
        onLongPress: widget.onDelete,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          key: SetRow.rowKey(widget.index),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 18,
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textMuted,
                  ),
                ),
              ),
              Expanded(child: Row(children: _fields())),
              _CheckButton(
                index: widget.index,
                completed: widget.entry.completed,
                onTap: _requestComplete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() {
    switch (widget.loadType) {
      case LoadType.weighted:
        return <Widget>[
          Expanded(
            child: StepperField(
            value: widget.entry.weightKg,
            step: 2.5,
            decimals: 1,
            isPrefill: widget.isPrefill,
            semanticsLabel: 'Weight in kilograms',
              onChanged: (v) => _emit(_copy(weightKg: v)),
            ),
          ),
          const _Unit('kg'),
          Expanded(
            child: StepperField(
            focusNode: _requiredFieldFocus,
            value: widget.entry.reps?.toDouble(),
            step: 1,
            isPrefill: widget.isPrefill,
            semanticsLabel: 'Repetitions',
              onChanged: (v) => _emit(_copy(reps: v?.round())),
            ),
          ),
          const _Unit('reps'),
        ];
      case LoadType.assisted:
        return <Widget>[
          Expanded(
            child: StepperField(
            value: widget.entry.assistKg,
            step: 2.5,
            decimals: 1,
            isPrefill: widget.isPrefill,
            semanticsLabel: 'Assistance in kilograms',
              onChanged: (v) => _emit(_copy(assistKg: v)),
            ),
          ),
          const _Unit('assist'),
          Expanded(
            child: StepperField(
            focusNode: _requiredFieldFocus,
            value: widget.entry.reps?.toDouble(),
            step: 1,
            isPrefill: widget.isPrefill,
            semanticsLabel: 'Repetitions',
              onChanged: (v) => _emit(_copy(reps: v?.round())),
            ),
          ),
          const _Unit('reps'),
        ];
      case LoadType.bodyweight:
        return <Widget>[
          Expanded(
            child: StepperField(
            focusNode: _requiredFieldFocus,
            value: widget.entry.reps?.toDouble(),
            step: 1,
            isPrefill: widget.isPrefill,
            semanticsLabel: 'Repetitions',
              onChanged: (v) => _emit(_copy(reps: v?.round())),
            ),
          ),
          const _Unit('reps'),
          _optionalWeight(
            value: widget.entry.addedKg,
            onChanged: (v) => _emit(_copy(addedKg: v)),
          ),
        ];
      case LoadType.timed:
        return <Widget>[
          Expanded(
            child: StepperField(
            focusNode: _requiredFieldFocus,
            value: widget.entry.durationSec?.toDouble(),
            step: 5,
            isPrefill: widget.isPrefill,
            semanticsLabel: 'Duration in seconds',
              onChanged: (v) => _emit(_copy(durationSec: v?.round())),
            ),
          ),
          _Unit(formatDuration(widget.entry.durationSec ?? 0)),
          _optionalWeight(
            value: widget.entry.weightKg,
            onChanged: (v) => _emit(_copy(weightKg: v)),
          ),
        ];
    }
  }

  /// Collapsed until tapped, so a user who never adds weight to a push-up never
  /// sees an input they have to skip past.
  Widget _optionalWeight({
    required double? value,
    required ValueChanged<double?> onChanged,
  }) {
    if (!_weightExpanded) {
      return Semantics(
        button: true,
        label: 'Add weight',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _weightExpanded = true),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: const Text(
              '+ weight',
              style: TextStyle(fontSize: 12.5, color: AppPalette.textSecondary),
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: Row(
        children: <Widget>[
          Expanded(
            child: StepperField(
              value: value,
              step: 2.5,
              decimals: 1,
              isPrefill: widget.isPrefill,
              semanticsLabel: 'Added weight in kilograms',
              onChanged: onChanged,
            ),
          ),
          const _Unit('kg'),
        ],
      ),
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, right: 5),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
        ),
      );
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.index,
    required this.completed,
    required this.onTap,
  });

  final int index;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: completed,
      label: 'Complete set ${index + 1}',
      excludeSemantics: true,
      child: GestureDetector(
        key: SetRow.checkKey(index),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: completed ? AppPalette.accentStrong : Colors.transparent,
                border: Border.all(
                  color:
                      completed ? AppPalette.accentStrong : AppPalette.border,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.check,
                size: 16,
                color: completed ? AppPalette.onAccent : AppPalette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
