import ActivityKit
import SwiftUI
import WidgetKit

// The home-screen widget (this week) and the open workout's Live Activity
// (`docs/adr/0008-the-week-lives-on-the-workout-landing.md`).
//
// Both draw only what the app handed them: the week from the App Group entry
// the app rewrites on every change, the activity from the content state the
// app pushes. Nothing here derives a figure, suggests a workout or reacts to a
// gap -- the same rules as the landing strip (ADR 0005).

/// The closed palette (`docs/00` §12), the roles this extension uses.
enum Palette {
  static let page = Color(red: 0x0E / 255, green: 0x0E / 255, blue: 0x0F / 255)
  static let surface = Color(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1A / 255)
  static let border = Color(red: 0x2E / 255, green: 0x2E / 255, blue: 0x32 / 255)
  static let chalk = Color(red: 0xED / 255, green: 0xED / 255, blue: 0xEB / 255)
  static let secondary = Color(red: 0xA3 / 255, green: 0xA3 / 255, blue: 0xA7 / 255)
  static let muted = Color(red: 0x8B / 255, green: 0x8B / 255, blue: 0x90 / 255)
  /// Shell amber: trained / active. A hit day, the done count.
  static let amber = Color(red: 0xFF / 255, green: 0xA5 / 255, blue: 0x3D / 255)
}

@main
struct TurtleLiftWidgetBundle: WidgetBundle {
  var body: some Widget {
    WeekWidget()
    if #available(iOS 16.2, *) {
      WorkoutLiveActivity()
    }
  }
}

// MARK: - This week

struct WeekEntry: TimelineEntry {
  let date: Date
  let week: WeekGlance
}

struct WeekProvider: TimelineProvider {
  func placeholder(in context: Context) -> WeekEntry {
    WeekEntry(date: Date(), week: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (WeekEntry) -> Void) {
    completion(WeekEntry(date: Date(), week: WeekGlance.read()))
  }

  /// One entry, refreshed by the app on change and again after midnight, when
  /// "today" moves and the app's next write will say so.
  func getTimeline(in context: Context, completion: @escaping (Timeline<WeekEntry>) -> Void) {
    let entry = WeekEntry(date: Date(), week: WeekGlance.read())
    let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60 + 60)
    completion(Timeline(entries: [entry], policy: .after(tomorrow)))
  }
}

struct WeekWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TurtleLiftWeek", provider: WeekProvider()) { entry in
      WeekWidgetView(week: entry.week)
        .widgetURL(GlanceStore.openWorkoutURL)
        .modifier(PageBackground())
    }
    .configurationDisplayName("This week")
    .description("Your training days and your last workout.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

/// The page colour behind a widget, the iOS 17 way where it exists.
struct PageBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(Palette.page, for: .widget)
    } else {
      content.padding().background(Palette.page)
    }
  }
}

struct DayMarker: View {
  let day: WeekGlance.Day

  var body: some View {
    VStack(spacing: 4) {
      ZStack {
        switch day.state {
        case "hit":
          Circle().fill(Palette.amber)
        case "ahead":
          Circle().strokeBorder(Palette.amber, lineWidth: 1.5)
        default:
          Circle().strokeBorder(Palette.muted, lineWidth: 1.5)
        }
      }
      .frame(width: 12, height: 12)
      Text(day.label)
        .font(.system(size: 12))
        .foregroundStyle(Palette.muted)
    }
  }
}

struct WeekWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let week: WeekGlance

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(week.headline)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Palette.chalk)
        .monospacedDigit()
        .lineLimit(2)
      if !week.caption.isEmpty {
        Text(week.caption)
          .font(.system(size: 12))
          .foregroundStyle(Palette.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 0)
      if !week.days.isEmpty {
        HStack(spacing: 8) {
          ForEach(week.days, id: \.self) { DayMarker(day: $0) }
        }
      }
      if family == .systemMedium, let last = week.lastWorkout {
        Text("Last workout · \(last)")
          .font(.system(size: 12))
          .foregroundStyle(Palette.muted)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

// MARK: - The open workout

@available(iOS 16.2, *)
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TurtleLiftActivityAttributes.self) { context in
      LockScreenView(state: context.state)
        .padding(16)
        .activityBackgroundTint(Palette.surface)
        .activitySystemActionForegroundColor(Palette.chalk)
        .widgetURL(GlanceStore.openWorkoutURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.state.title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.chalk)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          ClockText(start: context.state.clockStart)
            .font(.system(size: 15, weight: .semibold))
        }
        DynamicIslandExpandedRegion(.bottom) {
          DoneText(state: context.state).font(.system(size: 13))
        }
      } compactLeading: {
        Text("\(context.state.done)/\(context.state.total)")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Palette.amber)
          .monospacedDigit()
      } compactTrailing: {
        ClockText(start: context.state.clockStart)
          .font(.system(size: 13, weight: .semibold))
          .frame(maxWidth: 52)
      } minimal: {
        Text("\(context.state.done)")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Palette.amber)
      }
      .widgetURL(GlanceStore.openWorkoutURL)
    }
  }
}

/// "2 of 5 done", the count in amber because done means worked.
@available(iOS 16.2, *)
struct DoneText: View {
  let state: TurtleLiftActivityAttributes.ContentState

  var body: some View {
    (Text("\(state.done) of \(state.total)").foregroundColor(Palette.amber)
      + Text(" done").foregroundColor(Palette.secondary))
      .monospacedDigit()
  }
}

/// The elapsed clock, drawn by the system from the start date. Absent when the
/// app says the clock must not show; stops at six hours like the live screen.
struct ClockText: View {
  let start: Date?

  var body: some View {
    if let start {
      Text(timerInterval: start...start.addingTimeInterval(6 * 60 * 60), countsDown: false)
        .monospacedDigit()
        .foregroundStyle(Palette.chalk)
        .multilineTextAlignment(.trailing)
    }
  }
}

@available(iOS 16.2, *)
struct LockScreenView: View {
  let state: TurtleLiftActivityAttributes.ContentState

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Workout in progress")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Palette.secondary)
        Text(state.title)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Palette.chalk)
          .lineLimit(1)
        DoneText(state: state).font(.system(size: 13))
      }
      Spacer()
      ClockText(start: state.clockStart)
        .font(.system(size: 24, weight: .semibold))
        .frame(maxWidth: 120, alignment: .trailing)
    }
  }
}
