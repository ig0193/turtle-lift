import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/set_format.dart';
import '../theme/app_palette.dart';

/// A number the user can step or type.
///
/// **Both, not one or the other.** The keypad is how a value is set the first
/// time; the steppers are how it changes between sets, which is the far more
/// common action and the one happening one-handed with a bar still in the other
/// hand. Gym plates come in 2.5kg pairs, so that is the weight step.
///
/// **Unsigned, everywhere, by construction.** There is no minus key on the
/// keyboard and the steppers refuse to go below zero. The sign in this app is
/// carried by the load type — assistance is its own field on its own type —
/// never typed by the user.
///
/// **Muted until it is the user's own value.** A prefilled guess renders in the
/// muted colour so it is visibly distinct from something entered; whether a row
/// is a guess is decided by whether it exists in storage yet, not by a flag
/// this widget keeps.
class StepperField extends StatefulWidget {
  const StepperField({
    required this.value,
    required this.step,
    required this.onChanged,
    this.isPrefill = false,
    this.decimals = 0,
    this.semanticsLabel,
    this.focusNode,
    super.key,
  });

  /// The current value, or null for an empty field.
  final double? value;

  /// How much one tap of a stepper moves it: 2.5 for weight, 1 for reps, 5 for
  /// seconds.
  final double step;

  final ValueChanged<double?> onChanged;

  /// Whether this is still a guess carried over from the last session.
  final bool isPrefill;

  /// How many decimal places the field accepts. Weight takes one; reps and
  /// seconds take none.
  final int decimals;

  final String? semanticsLabel;

  /// Owned by the caller when it needs to focus this field — the set row does,
  /// because tapping the checkmark on an empty required field focuses it rather
  /// than completing the set.
  final FocusNode? focusNode;

  @override
  State<StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<StepperField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));
  /// Created only when the caller did not supply one, and disposed only then.
  FocusNode? _ownedFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  String _format(double? value) {
    if (value == null) return '';
    return widget.decimals == 0
        ? value.toStringAsFixed(0)
        : formatWeight(value);
  }

  @override
  void didUpdateWidget(StepperField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rewrite the field when the value changed underneath us and the user
    // is not mid-edit; otherwise the caret jumps while they are typing.
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // Only the node this widget made; a caller-supplied one is the caller's.
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _step(double delta) {
    final next = ((widget.value ?? 0) + delta).clamp(0, double.infinity);
    final rounded = widget.decimals == 0
        ? next.roundToDouble()
        : (next * 10).roundToDouble() / 10;
    _controller.text = _format(rounded);
    widget.onChanged(rounded);
  }

  @override
  Widget build(BuildContext context) {
    final colour =
        widget.isPrefill ? AppPalette.textMuted : AppPalette.textPrimary;

    return Semantics(
      label: widget.semanticsLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepButton(
            glyph: '−',
            semanticsLabel: 'Decrease',
            onTap: () => _step(-widget.step),
          ),
          // **Flexible, not a fixed width.** A weighted row carries two of
          // these plus their units, a set number and a checkmark, and at a
          // real phone's width the fixed version overflowed by 24 points —
          // which a test at a desk-sized viewport never sees.
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colour,
              ),
              // Unsigned, and decimal only where the field takes decimals.
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.decimals > 0,
                signed: false,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  widget.decimals > 0
                      ? RegExp(r'[0-9.]')
                      : RegExp(r'[0-9]'),
                ),
              ],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (text) =>
                  widget.onChanged(text.isEmpty ? null : double.tryParse(text)),
            ),
          ),
          _StepButton(
            glyph: '+',
            semanticsLabel: 'Increase',
            onTap: () => _step(widget.step),
          ),
        ],
      ),
    );
  }
}

/// One side of the stepper, at the app's 48pt tap-target floor even though the
/// glyph is small — this is used mid-set, one-handed.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.glyph,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String glyph;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 48,
          child: Center(
            child: Text(
              glyph,
              style: const TextStyle(
                fontSize: 17,
                color: AppPalette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
