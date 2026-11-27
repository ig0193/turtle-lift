import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// What the iOS system surfaces show: the Live Activity for an open workout
// and the home-screen widget's last workout
// (`docs/adr/0008-the-week-lives-on-the-workout-landing.md`, trimmed by
// `docs/adr/0015-diet-is-a-log.md`).
//
// **Told, never asked.** Every value here is derived in Dart at the moment it
// is sent and pushed whole; the native side keeps only the last thing it was
// told (the activity's content state, the widget's App Group entry) so it can
// draw without the app running. Nothing it holds is read back, so nothing it
// holds can go stale in a way the app would trust.

/// The one channel both surfaces go through. The Swift half is
/// `ios/Runner/GlanceChannel.swift`.
const MethodChannel kGlanceChannel =
    MethodChannel('dev.indresh.turtleLift/glance');

/// The open workout, as the Live Activity shows it.
@immutable
class SessionGlance {
  const SessionGlance({
    required this.title,
    required this.done,
    required this.total,
    required this.clockStart,
  });

  /// The resolved title (`docs/00` §6).
  final String title;

  /// Exercises done, of [total] on the list.
  final int done;
  final int total;

  /// When the live clock counts from, or null when the clock must not show
  /// (`sessionClockElapsed`'s rule). **A start time, never a duration**: the
  /// system draws the elapsed time itself with a timer text, and nothing
  /// stores how long the workout took.
  final DateTime? clockStart;

  Map<String, Object?> toJson() => <String, Object?>{
        'title': title,
        'done': done,
        'total': total,
        'clockStartMs': clockStart?.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      other is SessionGlance &&
      other.title == title &&
      other.done == done &&
      other.total == total &&
      other.clockStart == clockStart;

  @override
  int get hashCode => Object.hash(title, done, total, clockStart);
}

/// One day marker on the widget: its short name and `hit`, `empty` or `ahead`.
/// **Always empty now**: the training plan it marked is gone, and the type
/// stays because the widget's decoder still expects the `days` key.
@immutable
class GlanceDay {
  const GlanceDay(this.label, this.state);

  final String label;
  final String state;

  @override
  bool operator ==(Object other) =>
      other is GlanceDay && other.label == label && other.state == state;

  @override
  int get hashCode => Object.hash(label, state);
}

/// What the home-screen widget shows. See `weekGlanceProvider`: the last
/// workout travels in [headline], and [caption], [days] and [lastWorkout] are
/// empty, because the wire shape is the one the widget already decodes.
@immutable
class WeekGlance {
  const WeekGlance({
    required this.headline,
    required this.caption,
    required this.days,
    required this.lastWorkout,
  });

  /// "Yesterday · Push day · 14 sets", or the quiet line with no history.
  final String headline;

  /// Empty.
  final String caption;
  final List<GlanceDay> days;

  /// Null.
  final String? lastWorkout;

  Map<String, Object?> toJson() => <String, Object?>{
        'headline': headline,
        'caption': caption,
        'days': <Map<String, String>>[
          for (final d in days) <String, String>{'label': d.label, 'state': d.state},
        ],
        'lastWorkout': lastWorkout,
      };

  @override
  bool operator ==(Object other) =>
      other is WeekGlance &&
      other.headline == headline &&
      other.caption == caption &&
      listEquals(other.days, days) &&
      other.lastWorkout == lastWorkout;

  @override
  int get hashCode =>
      Object.hash(headline, caption, Object.hashAll(days), lastWorkout);
}

/// Where glances go. A seam so tests see what would be sent.
abstract interface class GlanceBridge {
  /// A Live Activity or home-screen widget was tapped: open the Workout tab.
  Stream<void> get openWorkoutTaps;

  Future<void> showSession(SessionGlance glance);
  Future<void> endSession();
  Future<void> showWeek(WeekGlance glance);
}

/// The real bridge: [kGlanceChannel] on iOS, nothing anywhere else.
///
/// **Never fails the app.** A platform without the Swift half (Android, a test
/// host, an iOS too old for Live Activities) answers with a missing-plugin or
/// platform error, and a glance is decoration: it is dropped.
class MethodChannelGlanceBridge implements GlanceBridge {
  MethodChannelGlanceBridge({bool? enabled})
      : _enabled = enabled ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    if (_enabled) {
      kGlanceChannel.setMethodCallHandler((call) async {
        if (call.method == 'openWorkout') _taps.add(null);
      });
    }
  }

  final bool _enabled;
  final StreamController<void> _taps = StreamController<void>.broadcast();

  @override
  Stream<void> get openWorkoutTaps => _taps.stream;

  Future<void> _call(String method, [Object? arguments]) async {
    if (!_enabled) return;
    try {
      await kGlanceChannel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // No native half here.
    } on PlatformException {
      // The OS declined (Live Activities off in Settings, say).
    }
  }

  @override
  Future<void> showSession(SessionGlance glance) =>
      _call('showSession', glance.toJson());

  @override
  Future<void> endSession() => _call('endSession');

  @override
  Future<void> showWeek(WeekGlance glance) => _call('showWeek', glance.toJson());
}

final glanceBridgeProvider =
    Provider<GlanceBridge>((ref) => MethodChannelGlanceBridge());
