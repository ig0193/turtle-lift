import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Predictive back is one manifest attribute, and its absence is invisible
/// where it is most likely to be tested. Android 16 (the repo's targetSdk 36)
/// turns the gesture on by default, so a current device or emulator behaves
/// correctly whether or not the flag is set -- only Android 13, 14 and 15 show
/// the regression, and only by silently not animating. The gesture itself
/// cannot be driven from `flutter_test`; the flag can, so the flag is what is
/// guarded here.
void main() {
  test('the Android manifest opts into the predictive back callback', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    // Strip comments first: a raw substring match would stay green with the
    // attribute commented out, which is the most likely way it gets disabled.
    final live = manifest.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    final application = RegExp(r'<application\b[^>]*>').firstMatch(live);
    expect(application, isNotNull,
        reason: 'the manifest should declare an application element');

    expect(
      application!.group(0),
      contains('android:enableOnBackInvokedCallback="true"'),
      reason: 'the attribute has to be live and on <application> -- commented '
          'out, or moved onto <activity>, predictive back is silently absent '
          'on Android 13, 14 and 15 and present on 16 regardless, so no device '
          'test catches its removal',
    );
  });
}
