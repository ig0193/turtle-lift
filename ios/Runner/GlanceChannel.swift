import Flutter
import Foundation
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit
#endif

/// The Swift half of `lib/src/data/glance_bridge.dart`: starts, updates and
/// ends the workout's Live Activity, hands the home-screen widget its week, and
/// tells Dart when either was tapped.
///
/// It keeps no state of its own beyond what the system holds for it (the
/// activity's content, the App Group entry), all of which Dart re-sends on
/// every change and at every boot.
final class GlanceChannel {
  static let name = "dev.indresh.turtleLift/glance"

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: GlanceChannel.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  /// A widget or activity tap: Dart switches to the Workout tab.
  func openWorkout() {
    channel.invokeMethod("openWorkout", arguments: nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showSession":
      if #available(iOS 16.2, *), let args = call.arguments as? [String: Any] {
        LiveSession.show(LiveSession.state(from: args))
      }
      result(nil)
    case "endSession":
      if #available(iOS 16.2, *) {
        LiveSession.end()
      }
      result(nil)
    case "showWeek":
      if let args = call.arguments,
        let data = try? JSONSerialization.data(withJSONObject: args)
      {
        UserDefaults(suiteName: GlanceStore.appGroup)?.set(data, forKey: GlanceStore.weekKey)
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

#if canImport(ActivityKit)
@available(iOS 16.2, *)
enum LiveSession {
  /// How long the system clock may run: the live screen's six-hour rule.
  static let clockLimit: TimeInterval = 6 * 60 * 60

  static func state(from args: [String: Any]) -> TurtleLiftActivityAttributes.ContentState {
    let startMs = args["clockStartMs"] as? NSNumber
    return TurtleLiftActivityAttributes.ContentState(
      title: args["title"] as? String ?? "Workout",
      done: (args["done"] as? NSNumber)?.intValue ?? 0,
      total: (args["total"] as? NSNumber)?.intValue ?? 0,
      clockStart: startMs.map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
    )
  }

  static func show(_ state: TurtleLiftActivityAttributes.ContentState) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let content = ActivityContent(
      state: state,
      staleDate: state.clockStart.map { $0.addingTimeInterval(clockLimit) }
    )
    let running = Activity<TurtleLiftActivityAttributes>.activities
    if let current = running.first {
      Task { await current.update(content) }
    } else {
      _ = try? Activity.request(
        attributes: TurtleLiftActivityAttributes(),
        content: content,
        pushType: nil
      )
    }
  }

  static func end() {
    for activity in Activity<TurtleLiftActivityAttributes>.activities {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
#endif
