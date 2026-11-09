import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// The open workout's Live Activity, shared by the app (which starts, updates
/// and ends it) and the widget extension (which draws it).
///
/// Everything in the state is derived in Dart and pushed whole
/// (`lib/src/data/glance_bridge.dart`). **The clock is a start date, never a
/// duration**: the system counts from it with a timer text, and nothing anywhere
/// stores how long the workout took (`docs/adr/0008`).
@available(iOS 16.1, *)
struct TurtleLiftActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// The resolved session title.
    var title: String
    /// Exercises done, of `total`.
    var done: Int
    var total: Int
    /// When the live clock counts from, or nil when it must not show (a
    /// backdated session, or one over six hours old).
    var clockStart: Date?
  }
}
#endif

/// Where the app hands the home-screen widget its week. Written whole on every
/// change, read by the widget's timeline; the app never reads it back.
enum GlanceStore {
  static let appGroup = "group.dev.indresh.turtleLift"
  static let weekKey = "week"

  /// The URL the widget and the activity open, which the app routes to the
  /// Workout tab.
  static let openWorkoutURL = URL(string: "turtlelift://workout")!
}

/// The week as the widget shows it; mirrors `WeekGlance.toJson()`.
struct WeekGlance: Codable {
  struct Day: Codable, Hashable {
    var label: String
    /// `hit`, `empty` or `ahead`.
    var state: String
  }

  var headline: String
  var caption: String
  var days: [Day]
  var lastWorkout: String?

  static let placeholder = WeekGlance(
    headline: "Pick training days",
    caption: "",
    days: [],
    lastWorkout: nil
  )

  static func read() -> WeekGlance {
    guard
      let data = UserDefaults(suiteName: GlanceStore.appGroup)?
        .data(forKey: GlanceStore.weekKey),
      let week = try? JSONDecoder().decode(WeekGlance.self, from: data)
    else { return .placeholder }
    return week
  }
}
