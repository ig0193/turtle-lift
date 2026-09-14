import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The placeholder, and the accessible name of the tappable variant.
///
/// **It names all three vocabularies** (R11): search here matches exercises,
/// muscles and equipment, and a field labelled "Search exercises" would teach
/// the user that the other two do not work. It is a const because two screens
/// render the same field and a second spelling of this line would read as two
/// different search boxes.
const String kMuscleSearchHint = 'Search exercises, muscles, equipment';

/// The Muscles tab's search box, in its two states.
///
/// **[MuscleSearchField.tappable] is not an input at all.** On the landing the
/// field is a button wearing a text field's clothes: tapping it pushes the
/// search screen rather than raising a keyboard in place. Filtering the landing
/// live was the alternative and it loses the map — the body and the 19 rows are
/// the landing's content, and a query would empty the screen the user is
/// standing on. So the landing keeps its content and search gets its own
/// screen, which is also what lets results carry three different kinds of row.
///
/// **One widget for both, rather than a box on the landing and a real field on
/// the search screen.** The two have to look identical — the push is meant to
/// feel like the field expanding, not like arriving somewhere new — and two
/// implementations of "our search box" would drift on the first padding change.
///
/// Every visual comes from `inputDecorationTheme` in
/// `lib/src/theme/app_theme.dart` rather than from arguments here; this widget
/// only chooses which of the two shapes to build.
class MuscleSearchField extends StatelessWidget {
  const MuscleSearchField._({
    this.onTap,
    this.controller,
    this.onChanged,
    this.autofocus = false,
    super.key,
  });

  /// The landing's field: read-only, and [onTap] is the push.
  const MuscleSearchField.tappable({
    required VoidCallback onTap,
    Key? key,
  }) : this._(onTap: onTap, key: key);

  /// The search screen's field: a real input.
  ///
  /// [autofocus] defaults to true because the only way to reach this screen is
  /// to tap the landing's field — the user has already said they want to type.
  const MuscleSearchField.editable({
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    bool autofocus = true,
    Key? key,
  }) : this._(
          controller: controller,
          onChanged: onChanged,
          autofocus: autofocus,
          key: key,
        );

  /// Non-null only for [MuscleSearchField.tappable], where it is also what
  /// makes the field read-only.
  final VoidCallback? onTap;

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// The field itself, so a test can find it without matching on placeholder
  /// copy that is allowed to change.
  @visibleForTesting
  static const Key fieldKey = ValueKey<String>('muscle-search-field');

  /// True for the landing's field.
  bool get _isButton => onTap != null;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      readOnly: _isButton,
      // The landing's field must never take focus: a caret blinking in a box
      // that cannot be typed into is the clearest way to promise an input and
      // not deliver one.
      canRequestFocus: !_isButton,
      style: kMuscleSearchTextStyle,
      cursorWidth: 1.6,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: kMuscleSearchHint,
        // Sized and coloured here rather than left to `IconTheme`: the icon
        // sits inside the field's own padding, so it has to match the 13.5pt
        // line beside it rather than the app's default icon size.
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: AppPalette.textMuted,
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 20),
      ),
    );

    if (!_isButton) return field;

    // The row pattern from `template_row.dart`, applied to a control that
    // happens to look like a field: announced as a button, hit as one opaque
    // box, and with the text field's own semantics excluded so a screen reader
    // does not offer to type into something that cannot be typed into.
    return Semantics(
      button: true,
      label: kMuscleSearchHint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Without this the field's own tap handling contests the gesture: a
        // read-only `TextField` still runs a selection gesture detector, and
        // which of the two wins is not something to leave to arbitration.
        child: IgnorePointer(child: field),
      ),
    );
  }
}

/// What the user types, and what the placeholder is measured against. The
/// prototype's `.search input` is 13.5px.
const TextStyle kMuscleSearchTextStyle = TextStyle(
  fontSize: 13.5,
  color: AppPalette.textPrimary,
);
