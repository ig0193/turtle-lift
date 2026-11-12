import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'template_row.dart' show kTemplateRowTitleStyle;

/// Small pieces the two editors (template, custom exercise) share, so they read
/// as one family with the rest of the app: the pinned bottom bar set logging
/// uses, outlined selection chips like the picker's muscle filter, and a field
/// painted from the palette.

/// A bar pinned under the scrollable, for the screen's one primary action —
/// the same shape as set logging's Mark exercise done bar.
class PinnedActionBar extends StatelessWidget {
  const PinnedActionBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        kScreenGutter + inset.left,
        8,
        kScreenGutter + inset.right,
        8 + inset.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppPalette.pageBackground,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: child,
    );
  }
}

/// A section heading inside an editor.
class EditorSectionLabel extends StatelessWidget {
  const EditorSectionLabel(this.text, {this.caption, super.key});

  final String text;

  /// One quiet line under the heading, when the choice needs explaining.
  final String? caption;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(text, style: kLandingSectionLabelStyle),
            ),
            if (caption != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                caption!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppPalette.textMuted,
                ),
              ),
            ],
          ],
        ),
      );
}

/// An outlined choice. Selected is the accent outline and label, like the
/// picker's muscle filter: selection controls are outlined, only the primary
/// action is filled (turtle-taste).
class SelectChip extends StatelessWidget {
  const SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colour = !enabled
        ? AppPalette.textMuted
        : selected
            ? AppPalette.accentStrong
            : AppPalette.textSecondary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: semanticsLabel ?? label,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppPalette.mutedSurface : AppPalette.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected && enabled
                  ? AppPalette.accentStrong
                  : AppPalette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colour,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single-line text field painted from the palette.
class EditorTextField extends StatelessWidget {
  const EditorTextField({
    required this.controller,
    required this.hint,
    this.maxLength,
    this.onChanged,
    this.autofocus = false,
    this.semanticsIdentifier,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: maxLength,
      onChanged: onChanged,
      // The keyboard covers the pinned action bar; tapping elsewhere or
      // Done puts it away.
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      style: kTemplateRowTitleStyle,
      cursorColor: AppPalette.accentStrong,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 15, color: AppPalette.textMuted),
        counterStyle: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
        filled: true,
        fillColor: AppPalette.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.accentStrong),
        ),
      ),
    );
    if (semanticsIdentifier == null) return field;
    return Semantics(identifier: semanticsIdentifier, child: field);
  }
}

/// A quiet text action, in the destructive colour when it deletes.
class EditorTextAction extends StatelessWidget {
  const EditorTextAction({
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.actionKey,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) => TextButton(
        key: actionKey,
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor:
              destructive ? AppPalette.danger : AppPalette.textSecondary,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      );
}
