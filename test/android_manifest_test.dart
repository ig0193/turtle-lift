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

  group('scheduled reminders (KTD14, ADR 0005)', () {
    late String live;

    setUp(() {
      live = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync()
          .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    });

    Iterable<String> permissions() => RegExp(
          r'<uses-permission\s+android:name="([^"]+)"',
        ).allMatches(live).map((m) => m.group(1)!);

    String? receiver(String name) => RegExp(
          '<receiver\\b[^>]*android:name="${RegExp.escape(name)}"'
          r'[^>]*?(?:/>|>[\s\S]*?</receiver>)',
        ).firstMatch(live)?.group(0);

    test('declares the notification and boot permissions', () {
      expect(
        permissions(),
        containsAll(<String>[
          'android.permission.POST_NOTIFICATIONS',
          'android.permission.RECEIVE_BOOT_COMPLETED',
        ]),
        reason: 'Android 13+ needs POST_NOTIFICATIONS to show anything, and '
            'reminders must survive a reboot',
      );
    });

    test('requests no exact-alarm permission', () {
      expect(
        permissions(),
        isNot(anyOf(
          contains('android.permission.SCHEDULE_EXACT_ALARM'),
          contains('android.permission.USE_EXACT_ALARM'),
        )),
        reason: 'reminders are inexact by design (ADR 0005 Consequences)',
      );
    });

    test('registers the plugin receivers, the boot one listening for boot',
        () {
      const prefix = 'com.dexterous.flutterlocalnotifications.';
      expect(receiver('${prefix}ScheduledNotificationReceiver'), isNotNull,
          reason: 'without it a scheduled notification never shows');
      final boot = receiver('${prefix}ScheduledNotificationBootReceiver');
      expect(boot, isNotNull);
      expect(boot, contains('android.intent.action.BOOT_COMPLETED'));
      expect(boot, contains('android.intent.action.MY_PACKAGE_REPLACED'));
      expect(boot, contains('android:exported="false"'));
    });
  });
}
