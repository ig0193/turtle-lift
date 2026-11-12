import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminder_scheduler.dart';

/// Whether the OS lets TurtleLift post notifications: null until first read,
/// then re-read whenever the app comes back to the foreground (the user may
/// have changed it in Settings meanwhile).
///
/// **Read by anything that summarises reminders** -- the Diet pane's
/// Reminders row says "Off in Settings" from it (profile audit B7, ADR 0014).
/// The Schedule and meal reminder screens push what they read into it too,
/// so every surface agrees. Never stored: it is the OS's answer, not ours.
class NotificationPermission extends Notifier<bool?> {
  @override
  bool? build() {
    final listener = AppLifecycleListener(onResume: refresh);
    ref.onDispose(listener.dispose);
    Future<void>.microtask(refresh);
    return null;
  }

  /// Asks the scheduler again. A platform without notifications reads false.
  Future<void> refresh() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final permitted = scheduler.isSupported && await scheduler.hasPermission();
    if (ref.mounted) state = permitted;
  }

  /// Records an answer a screen has just read or been given.
  void set(bool permitted) => state = permitted;
}

final notificationPermissionProvider =
    NotifierProvider<NotificationPermission, bool?>(NotificationPermission.new);

/// Opens the app's own page in the system Settings, where its notification
/// switch lives (profile audit B11). A provider so tests can swap it.
final openAppSettingsProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await const MethodChannel('dev.indresh.turtleLift/system')
          .invokeMethod<bool>('openSettings');
    } on MissingPluginException {
      // A platform with no handler (tests, desktop): nothing to open.
    } on PlatformException {
      // The OS refused; the note still says where to go.
    }
  },
);
