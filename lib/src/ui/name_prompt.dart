import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Asks for a short name and returns it, or null when the user backed out.
///
/// **Null and empty mean different things here.** Null is "cancelled"; an empty
/// string is "confirmed with nothing typed", which callers refuse rather than
/// creating a folder with no name. Collapsing the two would make Cancel and a
/// blank field indistinguishable to the caller.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirmLabel = 'Create',
}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title, style: const TextStyle(color: AppPalette.textPrimary)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        style: const TextStyle(color: AppPalette.textPrimary),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        decoration: const InputDecoration(
          counterText: '',
          hintText: 'Name',
          hintStyle: TextStyle(color: AppPalette.textMuted),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppPalette.textSecondary)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(controller.text.trim()),
          child: Text(confirmLabel,
              style: const TextStyle(color: AppPalette.accentLight)),
        ),
      ],
    ),
  );
  controller.dispose();
  return name;
}
