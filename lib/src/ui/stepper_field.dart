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
    this.unit,
    this.focusNode,
    this.min,
    this.max,
    super.key,
  });

  /// The unit, drawn small under the number inside the field ("kg", "reps").
  ///
  /// **Inside, not beside.** Beside the field it cost the row the width the
  /// steppers need to reach the 48pt tap-target floor on a small phone.
  final String? unit;

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

  /// The size the value is drawn at when it fits.
  static const double maxValueSize = 24;
  /// The lowest value the steppers reach, or null for the unsigned floor of 0.
  ///
  /// **Optional, and only an explicit bound spends a button.** A field that
  /// sets one (servings: 0.5 to 4) shows its stepper as disabled at the limit,
  /// so a tap that would do nothing is not offered. Without one, the floor is
  /// still 0 and the buttons behave exactly as they always have. Typed values
  /// are not clamped here: the caller decides what an out-of-range entry
  /// means.
  final double? min;

  /// The highest value the steppers reach, or null for no ceiling.
  final double? max;

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
  void initState() {
    super.initState();
    // Typing changes the text's width, and the fitted size below depends on
    // it, so a keystroke has to rebuild.
    _controller.addListener(_onText);
    // The box outlines in the accent while it is the field being typed in.
    _focusNode.addListener(_onFocus);
  }

  void _onText() => setState(() {});

  void _onFocus() => setState(() {});

  /// The largest size, from [StepperField.maxValueSize] down to 9, at which
  /// [text] fits [maxWidth].
  ///
  /// **The number is the hero.** It is what the user reads between sets, so it
  /// starts large and only gives ground when the box is narrow.
  ///
  /// **Shrink to fit rather than clip.** The field shares a row with a second
  /// stepper and a checkmark, so on a small phone "102.5" does not fit at the
  /// full size, and a clipped "102." is a wrong number on the screen that
  /// decides what goes on the bar.
  double _fittedSize(String text, double maxWidth, TextScaler scaler) {
    if (text.isEmpty || !maxWidth.isFinite) return StepperField.maxValueSize;
    for (var size = StepperField.maxValueSize; size > 9; size -= 0.5) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      // Clear of the box's rounded corners on both sides, not just inside it.
      final fits = painter.width <= maxWidth - 12;
      painter.dispose();
      if (fits) return size;
    }
    return 9;
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
    _controller
      ..removeListener(_onText)
      ..dispose();
    _focusNode.removeListener(_onFocus);
    // Only the node this widget made; a caller-supplied one is the caller's.
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _step(double delta) {
    final next = ((widget.value ?? 0) + delta)
        .clamp(widget.min ?? 0, widget.max ?? double.infinity);
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
    final value = widget.value ?? 0;
    final atMin = widget.min != null && value <= widget.min!;
    final atMax = widget.max != null && value >= widget.max!;

    return Semantics(
      label: widget.semanticsLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepButton(
            icon: Icons.remove_rounded,
            semanticsLabel: 'Decrease',
            onTap: atMin ? null : () => _step(-widget.step),
          ),
          // **Flexible, not a fixed width.** A weighted row carries two of
          // these plus their units, a set number and a checkmark, and at a
          // real phone's width the fixed version overflowed by 24 points —
          // which a test at a desk-sized viewport never sees.
          Expanded(
            // The value ignores the system text size: it is already the
            // largest type on the screen, and at 1.3x the steppers around it
            // grow until the box is narrower than "77.5". Fitting below is the
            // backstop.
            child: MediaQuery.withNoTextScaling(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? AppPalette.accentStrong
                        : AppPalette.border,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                // One height whatever the fitted size, so a weight that shrank
                // to fit does not leave its box shorter than the reps box
                // beside it.
                child: SizedBox(
                  height: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final size = _fittedSize(
                            _controller.text,
                            constraints.maxWidth,
                            MediaQuery.textScalerOf(context),
                          );
                          return TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: size,
                              fontWeight: FontWeight.w600,
                              color: colour,
                              // Steppers change the value in place; tabular
                              // digits keep it from shifting sideways as 77.5
                              // becomes 80.
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            // Unsigned, and decimal only where the field takes
                            // decimals.
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
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              // The box is drawn around the number and its
                              // unit together, so the field itself has none.
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              // An empty field says what goes in it rather
                              // than showing a blank box, which on a
                              // first-ever set reads as broken.
                              hintText: '0',
                              // Fainter than a prefilled guess (full
                              // textMuted), so "0" never reads as a value the
                              // app suggested.
                              hintStyle: TextStyle(
                                fontSize: size,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.textMuted
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            onChanged: (text) => widget.onChanged(
                                text.isEmpty ? null : double.tryParse(text)),
                          );
                        },
                      ),
                      if (widget.unit != null)
                        Text(
                          widget.unit!,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: AppPalette.textMuted,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            semanticsLabel: 'Increase',
            onTap: atMax ? null : () => _step(widget.step),
          ),
        ],
      ),
    );
  }
}

/// One side of the stepper, a full 48 x 48pt tap target even though the glyph
/// is small — this is used mid-set, one-handed.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticsLabel;

  /// Null at an explicit bound: the button is shown spent, not hidden, so the
  /// stepper keeps its shape.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticsLabel,
      // The tap is named here because excludeSemantics hides the
      // GestureDetector's own action from assistive tech.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: onTap == null
                  ? AppPalette.textMuted.withValues(alpha: 0.45)
                  : AppPalette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
