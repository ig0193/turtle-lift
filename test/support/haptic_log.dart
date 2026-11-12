import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every haptic the app asks the platform for, by its Flutter type
/// name (`HapticFeedbackType.selectionClick`, ...).
///
/// `HapticFeedback` goes through `SystemChannels.platform`, so a test sees
/// exactly what the engine would be told and nothing is played.
List<String> recordHaptics(WidgetTester tester) {
  final log = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        log.add(call.arguments as String? ?? 'vibrate');
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return log;
}

const String kHapticStep = 'HapticFeedbackType.selectionClick';
const String kHapticSetDone = 'HapticFeedbackType.mediumImpact';
const String kHapticSuccess = 'HapticFeedbackType.successNotification';
