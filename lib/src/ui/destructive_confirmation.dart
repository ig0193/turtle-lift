import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Asks before something permanent, in the colour that means permanent.
///
/// **One helper, because the app has two of these and they must match**:
/// discarding a workout in progress and deleting a saved one. Two hand-built
/// dialogs drift, and this is the pair where drift would matter.
///
/// **Painted explicitly from the app's own surfaces.** `app_theme.dart` sets no
/// dialog theme, so Material's defaults would bring an elevation and a surface
/// tint used nowhere else here.
///
/// **The action is `AppPalette.danger`, never the accent.** The accent means
/// "active / this has been worked" wherever it appears, so a delete
/// confirmation painted in it reads as approval. That is the whole reason a
/// separate destructive colour exists.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppPalette.border),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppPalette.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 13.5, color: AppPalette.textSecondary),
      ),
      actions: <Widget>[
        TextButton(
          key: confirmCancelKey,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppPalette.textSecondary),
          ),
        ),
        TextButton(
          key: confirmDestructiveKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: AppPalette.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The key a test taps to go through with it.
const Key confirmDestructiveKey = ValueKey<String>('confirm-destructive');

/// The key a test taps to back out.
const Key confirmCancelKey = ValueKey<String>('confirm-cancel');
