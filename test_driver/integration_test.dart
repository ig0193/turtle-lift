// Host side of `flutter drive` for `integration_test/taste_shots_test.dart`.
// Saves each screenshot the test takes to `$TASTE_SHOTS_DIR/<name>.png`
// (default `build/taste_shots`). See `tool/taste_shots.sh`.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final dir = Platform.environment['TASTE_SHOTS_DIR'] ?? 'build/taste_shots';
    final file = File('$dir/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
