import 'dart:async';

import 'package:turtle_lift/src/data/reminder_scheduler.dart';

/// One call to [FakeReminderScheduler.scheduleWeekly], as recorded.
typedef ScheduledReminder = ({
  int id,
  int weekday,
  int minute,
  String title,
  String body,
  ReminderTarget target,
});

/// A recording [ReminderScheduler] for widget and unit tests (KTD16).
///
/// Tests override `reminderSchedulerProvider` with this instead of touching
/// the platform channel. It keeps the pending set the way the OS would, so a
/// test can assert on what is scheduled after a cancel and a reschedule, and
/// [tap] plays a notification tap into [taps].
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.permitted = false, this.grantOnRequest = true});

  /// What [hasPermission] answers.
  bool permitted;

  /// Whether [requestPermission] grants (and so flips [permitted]).
  bool grantOnRequest;

  /// Every call, in order, as a short name: `cancelAll`, `cancelRange`,
  /// `schedule`, `request`.
  final List<String> calls = <String>[];

  /// What is pending now, by id.
  final Map<int, ScheduledReminder> pending = <int, ScheduledReminder>{};

  int cancelAllCount = 0;

  final StreamController<ReminderTarget> _taps =
      StreamController<ReminderTarget>.broadcast();

  /// Plays a notification tap for [target], as the plugin's callback would.
  void tap(ReminderTarget target) => _taps.add(target);

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    if (grantOnRequest) permitted = true;
    return permitted;
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
    calls.add('schedule');
    pending[id] = (
      id: id,
      weekday: weekday,
      minute: minute,
      title: title,
      body: body,
      target: target,
    );
  }

  @override
  Future<void> cancelRange(ReminderIdRange range) async {
    calls.add('cancelRange');
    pending.removeWhere((id, _) => range.contains(id));
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
    cancelAllCount++;
    pending.clear();
  }

  @override
  Stream<ReminderTarget> get taps => _taps.stream;
}
