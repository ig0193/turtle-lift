import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'meal_slot.dart';
import 'reminder_prefs.dart' show kLastMinuteOfDay;

/// Where a reminder tap takes the user (KTD17).
///
/// **The payload names a place, never a tab index.** A tab reorder must not
/// send an old pending notification to the wrong screen, and the OS keeps
/// these strings for weeks.
enum ReminderTarget {
  /// Profile, Diet segment, today (`docs/adr/0007-diet-in-profile.md`).
  dietToday('diet/today'),

  /// Profile, Schedule segment (ADR 0005).
  schedule('schedule');

  const ReminderTarget(this.payload);

  /// What the notification carries.
  final String payload;

  /// The target [payload] names, or null for anything else. The plugin turns
  /// a null payload into `''` on every platform, which routes nowhere.
  static ReminderTarget? fromPayload(String? payload) {
    for (final target in values) {
      if (target.payload == payload) return target;
    }
    return null;
  }
}

/// An inclusive range of notification ids one feature owns (KTD15).
@immutable
class ReminderIdRange {
  const ReminderIdRange(this.first, this.last);

  final int first;
  final int last;

  bool contains(int id) => id >= first && id <= last;

  @override
  bool operator ==(Object other) =>
      other is ReminderIdRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'ReminderIdRange($first-$last)';
}

/// The Schedule training-day reminders, one per weekday.
const ReminderIdRange kTrainingReminderIds = ReminderIdRange(100, 106);

/// The Diet morning summaries, one per weekday.
const ReminderIdRange kDietSummaryReminderIds = ReminderIdRange(200, 206);

/// The Diet meal reminders: 300 + weekday x 10 + slot index.
const ReminderIdRange kDietMealReminderIds = ReminderIdRange(300, 363);

void _checkWeekday(int weekday) {
  if (weekday < 0 || weekday > 6) {
    throw ArgumentError.value(weekday, 'weekday', 'must be 0 (Mon) to 6 (Sun)');
  }
}

/// The training reminder id for [weekday], 0 = Monday.
int trainingReminderId(int weekday) {
  _checkWeekday(weekday);
  return kTrainingReminderIds.first + weekday;
}

/// The Diet summary id for [weekday], 0 = Monday.
int dietSummaryReminderId(int weekday) {
  _checkWeekday(weekday);
  return kDietSummaryReminderIds.first + weekday;
}

/// The Diet meal reminder id for [slot] on [weekday], 0 = Monday.
int dietMealReminderId(int weekday, MealSlot slot) {
  _checkWeekday(weekday);
  return kDietMealReminderIds.first + weekday * 10 + slot.index;
}

/// The first moment after [now], in [now]'s zone, that falls on [weekday]
/// (0 = Monday) at [minute] past midnight, wall-clock.
///
/// Strictly after: a reminder for this very minute goes to next week, since
/// the OS would drop one scheduled in the past. Built from calendar fields
/// rather than by adding hours, so it keeps 08:00 across a clock change.
tz.TZDateTime nextWeeklyInstance(tz.TZDateTime now, int weekday, int minute) {
  _checkWeekday(weekday);
  if (minute < 0 || minute > kLastMinuteOfDay) {
    throw ArgumentError.value(minute, 'minute', 'must be 0 to 1439');
  }
  final daysAhead = (weekday + 1 - now.weekday) % 7;
  var candidate = tz.TZDateTime(now.location, now.year, now.month,
      now.day + daysAhead, minute ~/ 60, minute % 60);
  if (!candidate.isAfter(now)) {
    candidate = tz.TZDateTime(now.location, candidate.year, candidate.month,
        candidate.day + 7, minute ~/ 60, minute % 60);
  }
  return candidate;
}

/// Local, fixed-schedule notifications (ADR 0005 §3), behind a seam (KTD16).
///
/// Widget and unit tests override [reminderSchedulerProvider] with a recording
/// fake, the way `appDatabaseProvider` keeps them off the file system.
///
/// **What it does not do:** decide what to schedule. Callers build reminders
/// from the plan and the preferences, cancel their own [ReminderIdRange], and
/// schedule afresh; that "reschedule" is theirs (U16, U17).
abstract interface class ReminderScheduler {
  /// False where notifications cannot work (not initialised, or a platform
  /// without them). Every method below is then a quiet no-op.
  bool get isSupported;

  /// Whether the OS will currently show this app's notifications.
  Future<bool> hasPermission();

  /// Shows the OS prompt if the answer is still undetermined, and returns
  /// whether notifications are now allowed. Call only after the explain-first
  /// sheet (ADR 0005 §3); once the user has answered, the OS shows nothing.
  Future<bool> requestPermission();

  /// Schedules notification [id] every week on [weekday] (0 = Monday) at
  /// [minute] past local midnight. Replaces any pending notification with
  /// that id. A tap routes to [target].
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int minute,
    required String title,
    required String body,
    required ReminderTarget target,
  });

  /// Cancels every pending notification whose id is in [range].
  Future<void> cancelRange(ReminderIdRange range);

  /// Cancels every pending and shown notification. Delete all data calls it.
  Future<void> cancelAll();

  /// Taps on a notification while the app is running (a warm start). A cold
  /// start is read once by `initialize` instead, never from here.
  Stream<ReminderTarget> get taps;
}

/// One weekly notification a feature wants pending: the arguments to
/// [ReminderScheduler.scheduleWeekly], as a value a pure builder can return
/// and a test can compare.
@immutable
class WeeklyReminder {
  const WeeklyReminder({
    required this.id,
    required this.weekday,
    required this.minute,
    required this.title,
    required this.body,
    required this.target,
  });

  final int id;

  /// 0 = Monday.
  final int weekday;

  /// Minutes after local midnight.
  final int minute;
  final String title;
  final String body;
  final ReminderTarget target;

  @override
  bool operator ==(Object other) =>
      other is WeeklyReminder &&
      other.id == id &&
      other.weekday == weekday &&
      other.minute == minute &&
      other.title == title &&
      other.body == body &&
      other.target == target;

  @override
  int get hashCode => Object.hash(id, weekday, minute, title, body, target);

  @override
  String toString() =>
      'WeeklyReminder($id, weekday $weekday, minute $minute, $target)';
}

/// The KTD15 "reschedule": cancels everything pending in [range], then
/// schedules [reminders]. Idempotent, so it is safe at boot, on resume and
/// after every change.
///
/// Throws [ArgumentError] before touching the scheduler if a reminder's id is
/// outside [range]: it would survive the next cancel and fire forever.
Future<void> rescheduleRange(
  ReminderScheduler scheduler,
  ReminderIdRange range,
  List<WeeklyReminder> reminders,
) async {
  for (final r in reminders) {
    if (!range.contains(r.id)) {
      throw ArgumentError.value(r.id, 'id', 'is outside $range');
    }
  }
  await scheduler.cancelRange(range);
  for (final r in reminders) {
    await scheduler.scheduleWeekly(
      id: r.id,
      weekday: r.weekday,
      minute: r.minute,
      title: r.title,
      body: r.body,
      target: r.target,
    );
  }
}

/// [ReminderScheduler] over `flutter_local_notifications` (KTD14).
///
/// Inert until [initialize] succeeds, so a test or a widget that reaches it
/// without the boot sequence never touches a platform channel.
class PluginReminderScheduler implements ReminderScheduler {
  PluginReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    Future<String> Function()? localTimezone,
    tz.TZDateTime Function()? now,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _localTimezone = localTimezone ?? _deviceTimezone,
        _now = now ?? (() => tz.TZDateTime.now(tz.local));

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<String> Function() _localTimezone;
  final tz.TZDateTime Function() _now;
  final StreamController<ReminderTarget> _taps =
      StreamController<ReminderTarget>.broadcast();
  bool _ready = false;
  ReminderTarget? _unheard;

  static Future<String> _deviceTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  /// The one Android channel every reminder posts to.
  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Training-day and meal reminders you switched on.',
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  /// Loads the zone database, sets the device's zone as local, starts the
  /// plugin without asking for permission, and returns the target a
  /// notification launched the app with, or null.
  ///
  /// Called once per process, by `main()` before the first boot. **The launch
  /// details are the same for the life of the process**, which is why only
  /// the first boot may act on them (KTD17, AE8).
  Future<ReminderTarget?> initialize() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await _localTimezone()));
    } on Object {
      // An unknown or unreadable zone must not fail boot. UTC keeps the
      // reminders firing, an hour or so off, rather than not at all.
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final target = ReminderTarget.fromPayload(response.payload);
        if (target == null) return;
        // Before `runApp` nobody is listening yet, and a broadcast stream
        // drops what nobody hears. Keep the latest for the first listener.
        if (_taps.hasListener) {
          _taps.add(target);
        } else {
          _unheard = target;
        }
      },
    );
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch == null || !launch.didNotificationLaunchApp) return null;
    return ReminderTarget.fromPayload(launch.notificationResponse?.payload);
  }

  @override
  bool get isSupported => _ready;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _iosPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> hasPermission() async {
    if (!_ready) return false;
    final android = _androidPlugin;
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    final ios = _iosPlugin;
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _androidPlugin;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _iosPlugin;
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int minute,
    required String title,
    required String body,
    required ReminderTarget target,
  }) async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: nextWeeklyInstance(_now(), weekday, minute),
      notificationDetails: _details,
      // Inexact, so no exact-alarm permission is ever requested (ADR 0005).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: target.payload,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  @override
  Future<void> cancelRange(ReminderIdRange range) async {
    if (!_ready) return;
    for (final request in await _plugin.pendingNotificationRequests()) {
      if (range.contains(request.id)) await _plugin.cancel(id: request.id);
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  @override
  Stream<ReminderTarget> get taps async* {
    final unheard = _unheard;
    _unheard = null;
    if (unheard != null) yield unheard;
    yield* _taps.stream;
  }
}

/// The process's one plugin-backed scheduler. `main()` initialises it before
/// the first boot; until then, and in every test, it is inert.
final PluginReminderScheduler pluginReminderScheduler =
    PluginReminderScheduler();

/// The scheduler the app uses. Tests override it with a recording fake.
final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => pluginReminderScheduler);
