import 'package:flutter/material.dart';

import '../data/load_type.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'haptics.dart';
import 'motion.dart';
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
    this.lastTime,
    this.onUseLast,
    this.isPersonalBest = false,
    super.key,
  });

  /// Last time's value for this set, already worded ("Last 62.5kg × 6"), or
  /// null when last time had no such set. Derived by the caller from history;
  /// the row only shows it.
  final String? lastTime;

  /// Copies [lastTime] into the row. Null when there is nothing to copy.
  final VoidCallback? onUseLast;

  /// Whether this set is the exercise's record right now. Derived on every
  /// build by the caller (`personalBestSetIndex`), never stored.
  final bool isPersonalBest;

  /// The key a test taps to copy last time's value into row [index].
  static Key lastKey(int index) => ValueKey<String>('set-last-$index');

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

  /// Swipe-deletes seen by this slot; part of the Dismissible's key.
  int _dismissals = 0;

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
    // Completing is the event worth feeling; unticking is a correction.
    if (!widget.entry.completed) AppHaptics.setDone();
    widget.onToggleComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      // **Not keyed on the entry id.** A prefilled row's id is `ghost-N` until
      // its first keystroke saves it; a key that changed then rebuilt the
      // fields mid-typing, dropping focus, so "60" was stored as 6. The key
      // changes only after a swipe, so the next row that slides into this
      // slot gets a fresh, undismissed Dismissible.
      key: ValueKey<String>('dismiss-${widget.index}-$_dismissals'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        setState(() => _dismissals++);
        widget.onDelete();
      },
      background: const ColoredBox(color: AppPalette.danger),
      child: GestureDetector(
        // The second way to delete, so removing a set never depends on a swipe
        // the user cannot make one-handed.
        onLongPress: widget.onDelete,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          key: SetRow.rowKey(widget.index),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
            children: <Widget>[
              SizedBox(
                width: 20,
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textMuted,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
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
              if (widget.lastTime != null || widget.isPersonalBest)
                _SecondLine(
                  index: widget.index,
                  lastTime: widget.lastTime,
                  onUseLast: widget.onUseLast,
                  isPersonalBest: widget.isPersonalBest,
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
            settled: widget.entry.completed,
            semanticsLabel: 'Weight in kilograms',
            semanticsIdentifier: 'set-${widget.index}-weight',
            unit: 'kg',
              onChanged: (v) => _emit(_copy(weightKg: v)),
            ),
          ),
          Expanded(
            child: StepperField(
            focusNode: _requiredFieldFocus,
            value: widget.entry.reps?.toDouble(),
            step: 1,
            isPrefill: widget.isPrefill,
            settled: widget.entry.completed,
            semanticsLabel: 'Repetitions',
            semanticsIdentifier: 'set-${widget.index}-reps',
            unit: 'reps',
              onChanged: (v) => _emit(_copy(reps: v?.round())),
            ),
          ),
        ];
      case LoadType.assisted:
        return <Widget>[
          Expanded(
            child: StepperField(
            value: widget.entry.assistKg,
            step: 2.5,
            decimals: 1,
            isPrefill: widget.isPrefill,
            settled: widget.entry.completed,
            semanticsLabel: 'Assistance in kilograms',
            semanticsIdentifier: 'set-${widget.index}-assist',
            unit: 'kg assist',
              onChanged: (v) => _emit(_copy(assistKg: v)),
            ),
          ),
          Expanded(
            child: StepperField(
            focusNode: _requiredFieldFocus,
            value: widget.entry.reps?.toDouble(),
            step: 1,
            isPrefill: widget.isPrefill,
            settled: widget.entry.completed,
            semanticsLabel: 'Repetitions',
            semanticsIdentifier: 'set-${widget.index}-reps',
            unit: 'reps',
              onChanged: (v) => _emit(_copy(reps: v?.round())),
            ),
          ),
        ];
      case LoadType.bodyweight:
        return <Widget>[
          Expanded(
            child: StepperField(
            focusNode: _requiredFieldFocus,
            value: widget.entry.reps?.toDouble(),
            step: 1,
            isPrefill: widget.isPrefill,
            settled: widget.entry.completed,
            semanticsLabel: 'Repetitions',
            semanticsIdentifier: 'set-${widget.index}-reps',
            unit: 'reps',
              onChanged: (v) => _emit(_copy(reps: v?.round())),
            ),
          ),
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
            settled: widget.entry.completed,
            semanticsLabel: 'Duration in seconds',
            semanticsIdentifier: 'set-${widget.index}-duration',
            // "sec" until there is a value, then the value as m:ss -- "0:00"
            // under an empty field reads as a reading, not a prompt.
            unit: widget.entry.durationSec == null
                ? 'sec'
                : formatDuration(widget.entry.durationSec!),
              onChanged: (v) => _emit(_copy(durationSec: v?.round())),
            ),
          ),
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
        container: true,
        button: true,
        label: 'Add weight',
        identifier: 'set-${widget.index}-add-weight',
        onTap: () => setState(() => _weightExpanded = true),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _weightExpanded = true),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppPalette.textSecondary,
                ),
                SizedBox(width: 4),
                Text(
                  'weight',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppPalette.textSecondary,
                  ),
                ),
              ],
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
              settled: widget.entry.completed,
              semanticsLabel: 'Added weight in kilograms',
              semanticsIdentifier: 'set-${widget.index}-added',
              unit: 'kg',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
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
      container: true,
      button: true,
      checked: completed,
      label: 'Complete set ${index + 1}',
      identifier: 'set-$index-check',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: SetRow.checkKey(index),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration:
                  motionDuration(context, const Duration(milliseconds: 150)),
              curve: Curves.easeOut,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: completed ? AppPalette.accentStrong : Colors.transparent,
                border: Border.all(
                  color:
                      completed ? AppPalette.accentStrong : AppPalette.border,
                ),
                borderRadius: BorderRadius.circular(8),
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

/// The quiet line under a set: last time's value, which copies into the row
/// on a tap, and the PB mark when this set is the record.
///
/// **In the row, not in a block below.** Rows are filled in from last time,
/// but once a value is changed the comparison would be gone; Hevy and JEFIT
/// keep it beside the set for that reason. The Recent block stays below for
/// the multi-session view.
class _SecondLine extends StatelessWidget {
  const _SecondLine({
    required this.index,
    required this.lastTime,
    required this.onUseLast,
    required this.isPersonalBest,
  });

  final int index;
  final String? lastTime;
  final VoidCallback? onUseLast;
  final bool isPersonalBest;

  @override
  Widget build(BuildContext context) {
    final last = lastTime;
    return Row(
      children: <Widget>[
        // Under the fields, not the set number.
        const SizedBox(width: 20),
        Expanded(
          child: last == null
              ? const SizedBox(height: 48)
              : Semantics(
                  container: true,
                  button: true,
                  label: '$last. Use for set ${index + 1}',
                  onTap: onUseLast,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: SetRow.lastKey(index),
                    behavior: HitTestBehavior.opaque,
                    onTap: onUseLast,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        if (isPersonalBest)
          Semantics(
            label: 'Personal best',
            excludeSemantics: true,
            child: const SizedBox(
              width: 48,
              child: Center(child: Text('PB', style: kPbMarkStyle)),
            ),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}

