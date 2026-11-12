import 'package:flutter/services.dart';

/// The app's haptic vocabulary: three patterns, each with one meaning.
///
/// **Defined once, so a meaning cannot drift.** HIG asks for "a clear, causal
/// relationship" between a haptic and what caused it, and warns against
/// overusing them; Android asks that more important events feel stronger. So
/// the strength follows the weight of the event, and nothing else in the app
/// plays one:
///
/// | call | pattern | when |
/// |---|---|---|
/// | [step] | selection click | each + or - tap on a stepper |
/// | [setDone] | medium impact | a set is ticked complete (not unticked) |
/// | [success] | success notification | Mark exercise done, and a Finish that saved |
///
/// Nothing on scroll, navigation, typing or a refused tap.
///
/// **Platform settings are honoured by the platform.** Flutter's
/// `HapticFeedback` goes to `UIFeedbackGenerator` on iOS, which plays nothing
/// when System Haptics is off, and to `View.performHapticFeedback` on Android,
/// which follows the touch-feedback setting. There is no in-app switch to keep
/// in sync with them, and no plugin.
abstract final class AppHaptics {
  /// A value moved by one step.
  static Future<void> step() => HapticFeedback.selectionClick();

  /// A set was completed.
  static Future<void> setDone() => HapticFeedback.mediumImpact();

  /// An exercise or a workout was finished and saved.
  static Future<void> success() => HapticFeedback.successNotification();
}
