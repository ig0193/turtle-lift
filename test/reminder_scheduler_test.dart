import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:turtle_lift/src/data/meal_slot.dart';
import 'package:turtle_lift/src/data/reminder_scheduler.dart';

/// The notification layer under the fake (KTD14-KTD17): deterministic ids, the
/// weekly trigger, the tap payload, and the plugin adapter driven through a
/// stand-in plugin so no test reaches a platform channel.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('reminder ids (KTD15)', () {
    test('training is 100-106, one per weekday', () {
      expect([for (var d = 0; d < 7; d++) trainingReminderId(d)],
          [100, 101, 102, 103, 104, 105, 106]);
      expect(kTrainingReminderIds, const ReminderIdRange(100, 106));
    });

    test('the diet summary is 200-206', () {
      expect([for (var d = 0; d < 7; d++) dietSummaryReminderId(d)],
          [200, 201, 202, 203, 204, 205, 206]);
      expect(kDietSummaryReminderIds, const ReminderIdRange(200, 206));
    });

    test('a diet meal is 300 + weekday x 10 + slot', () {
      expect(dietMealReminderId(0, MealSlot.breakfast), 300);
      expect(dietMealReminderId(2, MealSlot.lunch), 321);
      expect(dietMealReminderId(6, MealSlot.dinner), 363);
      expect(kDietMealReminderIds, const ReminderIdRange(300, 363));
    });

    test('all 42 are distinct, inside their own range and under the iOS cap '
        'of 64 pending', () {
      final ids = <int>{
        for (var d = 0; d < 7; d++) ...{
          trainingReminderId(d),
          dietSummaryReminderId(d),
          for (final slot in MealSlot.values) dietMealReminderId(d, slot),
        },
      };
      expect(ids, hasLength(42));
      expect(ids.length, lessThan(64));
      for (var d = 0; d < 7; d++) {
        expect(kTrainingReminderIds.contains(trainingReminderId(d)), isTrue);
        expect(
            kDietSummaryReminderIds.contains(dietSummaryReminderId(d)), isTrue);
        for (final slot in MealSlot.values) {
          final id = dietMealReminderId(d, slot);
          expect(kDietMealReminderIds.contains(id), isTrue);
          expect(kTrainingReminderIds.contains(id), isFalse);
          expect(kDietSummaryReminderIds.contains(id), isFalse);
        }
      }
    });

    test('a weekday outside 0-6 is refused', () {
      expect(() => trainingReminderId(7), throwsArgumentError);
      expect(() => dietSummaryReminderId(-1), throwsArgumentError);
      expect(() => dietMealReminderId(7, MealSlot.lunch), throwsArgumentError);
    });
  });

  group('the tap payload (KTD17)', () {
    test('diet/today and schedule round-trip, never a tab index', () {
      expect(ReminderTarget.dietToday.payload, 'diet/today');
      expect(ReminderTarget.schedule.payload, 'schedule');
      for (final target in ReminderTarget.values) {
        expect(ReminderTarget.fromPayload(target.payload), target);
      }
    });

    test('an empty, unknown or missing payload routes nowhere', () {
      // The plugin coalesces a null payload to '' on every platform.
      expect(ReminderTarget.fromPayload(null), isNull);
      expect(ReminderTarget.fromPayload(''), isNull);
      expect(ReminderTarget.fromPayload('3'), isNull);
      expect(ReminderTarget.fromPayload('diet'), isNull);
    });
  });

  group('the next weekly instance', () {
    tz.Location london() => tz.getLocation('Europe/London');

    tz.TZDateTime at(int y, int m, int d, int h, int min) =>
        tz.TZDateTime(london(), y, m, d, h, min);

    // 2026-11-04 is a Wednesday (weekday 2).
    test('later today is today', () {
      expect(nextWeeklyInstance(at(2026, 11, 4, 9, 0), 2, 13 * 60),
          at(2026, 11, 4, 13, 0));
    });

    test('earlier today, or this very minute, is next week', () {
      expect(nextWeeklyInstance(at(2026, 11, 4, 14, 0), 2, 13 * 60),
          at(2026, 11, 11, 13, 0));
      expect(nextWeeklyInstance(at(2026, 11, 4, 13, 0), 2, 13 * 60),
          at(2026, 11, 11, 13, 0));
    });

    test('another weekday is the next one of it, Monday 0 to Sunday 6', () {
      expect(nextWeeklyInstance(at(2026, 11, 4, 9, 0), 0, 8 * 60),
          at(2026, 11, 9, 8, 0));
      expect(nextWeeklyInstance(at(2026, 11, 4, 9, 0), 6, 20 * 60 + 30),
          at(2026, 11, 8, 20, 30));
    });

    test('keeps the wall-clock time across a daylight-saving change', () {
      // UK clocks go forward on Sunday 2027-03-28.
      final next = nextWeeklyInstance(at(2027, 3, 27, 9, 0), 0, 8 * 60);
      expect(next, at(2027, 3, 29, 8, 0));
      expect(next.hour, 8);
      expect(next.timeZoneOffset, const Duration(hours: 1));
    });

    test('a weekday or minute out of range is refused', () {
      expect(() => nextWeeklyInstance(at(2026, 11, 4, 9, 0), 7, 0),
          throwsArgumentError);
      expect(() => nextWeeklyInstance(at(2026, 11, 4, 9, 0), 0, 1440),
          throwsArgumentError);
    });
  });

  group('the plugin adapter', () {
    late _StubPlugin plugin;
    late PluginReminderScheduler scheduler;

    setUp(() {
      plugin = _StubPlugin();
      scheduler = PluginReminderScheduler(
        plugin: plugin,
        localTimezone: () async => 'Asia/Kolkata',
        now: () => tz.TZDateTime(
            tz.getLocation('Asia/Kolkata'), 2026, 11, 4, 9, 0),
      );
    });

    test('does nothing until initialised, so a test that never boots it '
        'cannot reach the platform', () async {
      expect(scheduler.isSupported, isFalse);
      await scheduler.scheduleWeekly(
        id: 321,
        weekday: 2,
        minute: 13 * 60,
        title: 't',
        body: 'b',
        target: ReminderTarget.dietToday,
      );
      await scheduler.cancelRange(kDietMealReminderIds);
      await scheduler.cancelAll();
      expect(await scheduler.hasPermission(), isFalse);
      expect(await scheduler.requestPermission(), isFalse);
      expect(plugin.calls, isEmpty);
    });

    test('initialise sets the local zone and returns no payload on a normal '
        'launch', () async {
      expect(await scheduler.initialize(), isNull);
      expect(scheduler.isSupported, isTrue);
      expect(tz.local.name, 'Asia/Kolkata');
      expect(plugin.calls, contains('initialize'));
      expect(plugin.requestedPermissionsAtInit, isFalse,
          reason: 'permission is asked only after the explain-first sheet, '
              'never at launch (ADR 0005 §3)');
    });

    test('initialise returns the target a notification launched the app with',
        () async {
      plugin.launchDetails = const NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'diet/today',
        ),
      );
      expect(await scheduler.initialize(), ReminderTarget.dietToday);
    });

    test('a launch that was not from a notification carries no target',
        () async {
      plugin.launchDetails = const NotificationAppLaunchDetails(
        false,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'diet/today',
        ),
      );
      expect(await scheduler.initialize(), isNull);
    });

    test('a zone the device reports but the database lacks falls back to UTC '
        'rather than failing boot', () async {
      final odd = PluginReminderScheduler(
        plugin: plugin,
        localTimezone: () async => 'Mars/Olympus_Mons',
      );
      expect(await odd.initialize(), isNull);
      expect(tz.local.name, anyOf('UTC', 'Etc/UTC'));
    });

    test('a warm tap lands on the taps stream as its target', () async {
      await scheduler.initialize();
      final taps = <ReminderTarget>[];
      final sub = scheduler.taps.listen(taps.add);
      addTearDown(sub.cancel);

      plugin.onResponse!(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'diet/today',
      ));
      plugin.onResponse!(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '',
      ));
      await pumpEventQueue();

      expect(taps, [ReminderTarget.dietToday]);
    });

    test('a tap that lands before the app is listening is kept for the first '
        'listener, not dropped', () async {
      // The plugin is initialised before `runApp`, so a tap delivered in that
      // gap has no listener yet. The latest one waits for the tap listener.
      await scheduler.initialize();
      plugin.onResponse!(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'schedule',
      ));

      final first = <ReminderTarget>[];
      final sub = scheduler.taps.listen(first.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(first, [ReminderTarget.schedule]);

      final second = <ReminderTarget>[];
      final again = scheduler.taps.listen(second.add);
      addTearDown(again.cancel);
      await pumpEventQueue();
      expect(second, isEmpty, reason: 'a kept tap is delivered once');
    });

    test('scheduleWeekly repeats on day and time, inexactly, with the payload',
        () async {
      await scheduler.initialize();
      await scheduler.scheduleWeekly(
        id: 321,
        weekday: 2,
        minute: 13 * 60,
        title: 'Lunch',
        body: '28 g planned',
        target: ReminderTarget.dietToday,
      );

      final call = plugin.scheduled.single;
      expect(call.id, 321);
      expect(call.title, 'Lunch');
      expect(call.body, '28 g planned');
      expect(call.payload, 'diet/today');
      expect(call.matchDateTimeComponents, DateTimeComponents.dayOfWeekAndTime,
          reason: 'a weekly trigger needs no app open to stay current (KTD15)');
      expect(call.androidScheduleMode, AndroidScheduleMode.inexactAllowWhileIdle,
          reason: 'no exact-alarm permission (ADR 0005)');
      expect(call.scheduledDate.weekday, DateTime.wednesday);
      expect(call.scheduledDate.hour, 13);
      expect(call.scheduledDate.minute, 0);
      expect(call.scheduledDate.location.name, 'Asia/Kolkata');
    });

    test('cancelRange cancels only the pending ids inside the range',
        () async {
      await scheduler.initialize();
      plugin.pending = const <PendingNotificationRequest>[
        PendingNotificationRequest(103, null, null, null),
        PendingNotificationRequest(205, null, null, null),
        PendingNotificationRequest(321, null, null, null),
        PendingNotificationRequest(363, null, null, null),
      ];

      await scheduler.cancelRange(kDietMealReminderIds);

      expect(plugin.cancelled, unorderedEquals(<int>[321, 363]));
    });

    test('cancelAll reaches the plugin', () async {
      await scheduler.initialize();
      await scheduler.cancelAll();
      expect(plugin.calls, contains('cancelAll'));
    });
  });
}

typedef _ScheduleCall = ({
  int id,
  String? title,
  String? body,
  String? payload,
  tz.TZDateTime scheduledDate,
  AndroidScheduleMode androidScheduleMode,
  DateTimeComponents? matchDateTimeComponents,
});

/// Stands in for the plugin singleton. `implements` rather than a subclass,
/// because the plugin's only constructor is private.
class _StubPlugin implements FlutterLocalNotificationsPlugin {
  final List<String> calls = <String>[];
  final List<_ScheduleCall> scheduled = <_ScheduleCall>[];
  final List<int> cancelled = <int>[];
  List<PendingNotificationRequest> pending =
      const <PendingNotificationRequest>[];
  NotificationAppLaunchDetails? launchDetails;
  DidReceiveNotificationResponseCallback? onResponse;
  bool? requestedPermissionsAtInit;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    calls.add('initialize');
    onResponse = onDidReceiveNotificationResponse;
    final darwin = settings.iOS;
    requestedPermissionsAtInit = darwin == null
        ? null
        : darwin.requestAlertPermission ||
            darwin.requestBadgePermission ||
            darwin.requestSoundPermission;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => launchDetails;

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    calls.add('zonedSchedule');
    scheduled.add((
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: scheduledDate,
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: matchDateTimeComponents,
    ));
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      pending;

  @override
  Future<void> cancel({required int id, String? tag}) async {
    calls.add('cancel');
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async => calls.add('cancelAll');

  @override
  T? resolvePlatformSpecificImplementation<
          T extends FlutterLocalNotificationsPlatform>() =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
