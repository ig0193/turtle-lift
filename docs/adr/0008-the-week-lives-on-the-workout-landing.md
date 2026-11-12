# 8. The week lives on the Workout landing

Date: 2026-11-09

## Status

Accepted (the user approved the research recommendations, then the follow-up
items). **Amends [ADR 0004](0004-profile-returns-as-a-tab.md)** (where the
derived week summary lives) **and [ADR 0005](0005-schedule-and-opt-in-notifications.md)**
(where a training reminder lands). **Amends `docs/00` §5, §9, §11, §12 and
§13** for the items below. Research: `docs/research/navigation-and-workout-tab.md`.

## Context

The research asked two questions: where Schedule should live, and how to make
the Workout tab stand out. Its answer to the first was to split Schedule by job:
the plan the user types is a rarely changed setting, and the week it produces is
a glance the user wants every time they open the app to train. Its answer to the
second was a set of polish and hierarchy changes, some of which touch rules in
`docs/00` and ADRs 0004–0006.

## Decision

### 1. The plan stays on Profile; the week moves beside Start

- **Profile › Schedule keeps what the user types**: the training-day chips, the
  Remind me switch and the time. It loses the "Your week" card and the "Last
  week" row, so Profile is authored data only again.
- **The Workout landing gains a "this week" strip** above the search field, at
  the tab root only (never on the landing pushed over an open workout): the
  plan's day markers (hits filled amber, amber's existing meaning), `N of M this
  week`, and the same caption as before (`2 more to go. Next is Wednesday`).
  With no plan it is one quiet line, `Pick training days`; with a plan that has
  no day left this week it says when the first plan day is. Tapping either opens
  Profile › Schedule. Derived on read (`thisWeekSummaryProvider`); nothing is
  stored. "Last week" is dropped rather than moved (decision for the user, below).
- **A "last workout" line** sits under the strip: `Yesterday · Push day · 14
  sets`, the newest saved workout exactly as its History row words it, opening
  that workout's History detail. It is a pointer to History, not a second figure.
- **The placement rule becomes:** derived lives on History, *except the current
  week and the pointer to the last workout, which live beside Start*; authored
  lives on Profile. ADR 0004's Schedule exception moves here under the same
  condition: the week never also renders on History, the summary card or the
  share card. The Diet exception (ADR 0007) is unchanged.
- **ADR 0005 rules 1 and 5 hold on the strip**: counts and days only, never a
  verdict ("missed", "behind") and never a workout, exercise or template name.
  `test/week_strip_test.dart` guards it.

### 2. A training reminder opens the Workout tab

The related content of "today is a training day" is the place training starts,
not the form that scheduled it (HIG Notifications). `ReminderTarget.schedule`
becomes `ReminderTarget.workout`, which selects the Workout tab after popping to
the shell. **Its payload stays the string `schedule`**, so notifications the OS
already holds still route. Diet reminders still open Profile › Diet.

### 3. Planned muscles are outlined in a neutral grey

The live map outlined planned muscles in amber, so before a single set the map
read as partly done. Planned-but-not-worked muscles are now outlined in
`textSecondary` (`#A3A3A7`); amber still means worked, steel still means the
secondary muscle and nothing else. `docs/00` §5 and §12 say so.

### 4. Sharing the summary card as an image

`Share card` under the summary card renders that card (a `RepaintBoundary`) to a
PNG and opens the **system share sheet** (`share_plus`, already a dependency).
**"No social features" (`docs/00` §13) still holds:** there is no feed, account,
follower, like, link or upload; the user exports an image of their own card to
wherever they choose, exactly as Export does with their data. The card keeps the
tracked-caps `TURTLELIFT` wordmark: it is the one deliberate exception to the
sentence-case rule (turtle-taste already names it). On a record day the card's
PB count takes the kcal slot (and the add-weight note is not shown), because an
estimate with an info icon is the weakest figure on a card meant to be shown.

### 5. "Do again"

A saved workout's History detail has `Do again`: a new open session, dated
today, with that workout's logged exercises in order (and its template name, if
it had one) and **no set values** — last time reaches each row as its derived
"last" line and prefill. It is user-initiated from a workout the user opened, so
it is not a "today's workout" suggestion. A workout already open is never
replaced silently: the user is asked, then it is saved (with a completed set) or
dropped, as starting any new workout does.

### 6. Ready-made recedes for a returning user

Once the user has a template of their own or three saved workouts (derived on
read), the eleven ready-made tiles fold behind one `Ready-made · 11` row. The
open/closed state is in memory only; search still finds every template.

### 7. A Live Activity and a home-screen widget (iOS)

- **Live Activity** for an open workout, lock screen and Dynamic Island: the
  resolved title, `N of M done`, and the elapsed clock as a **system timer
  text counting from the session's start date**. No duration is stored or
  computed for it; the clock appears only under the live screen's own rule (a
  session dated the day it started, under six hours old) and stops at six hours.
  It starts when logging starts, updates as exercises are done, and ends on
  Finish, Discard, and the reboot after Delete all data. It never reacts to
  inactivity.
- **Home-screen widget** (small and medium): this week's strip and, on medium,
  the last workout line, in the landing's own words. The app writes the whole
  week to an App Group entry on every change and reloads the timeline; the widget
  derives nothing.
- Tapping either opens the Workout tab (`turtlelift://workout`, routed like a
  training reminder). Flutter deep linking is off; this is the only URL.
- **Built without plugins**: one method channel (`dev.indresh.turtleLift/glance`,
  `lib/src/data/glance_bridge.dart` ↔ `ios/Runner/GlanceChannel.swift`) and one
  widget extension target (`ios/TurtleLiftWidgets`, iOS 17+), sharing
  `ios/Shared/TurtleLiftActivityAttributes.swift`. Runner and the extension carry
  the App Group `group.dev.indresh.turtleLift`. (`home_widget` and
  `live_activities` both ship `Package.swift`; they were not needed for this
  little native code.) **Android: no widget or ongoing notification** in V1; the
  bridge is a no-op there.

### Smaller changes in the same pass (no rule changed)

Haptics with fixed meanings (`AppHaptics`); Mark exercise done pinned in a bottom
bar on set logging; last time's value inside each set row, tap to copy; a done
set fades its steppers; the PB mark on the row the moment a set is a record
(`personalBestSetIndex`, the assisted inversion included); the live map eases a
newly worked muscle into its fill and is larger; the live header shows the
resolved title instead of "Name this workout"; the ready view lists the planned
exercises and Discard is quieter; a Recent group leads the exercise picker; every
animation honours Reduce Motion (`lib/src/ui/motion.dart`).

## Consequences

- `docs/00` §5, §9, §11, §12, §13, `docs/02`, `docs/04` and `CLAUDE.md` are
  reworded to match. **No schema change.**
- `lastWeekSummaryProvider` has no screen now; it is kept (tested) for the user's
  decision below.
- The iOS project gains an app-extension target and entitlements. A simulator
  build needs no paid team; a device or store build needs the App Group
  registered for both bundle ids (`dev.indresh.turtleLift`,
  `dev.indresh.turtleLift.Widgets`).
- **Left for the user:** whether "Last week" should come back as a second line on
  the strip; whether the no-plan line should be absent instead of `Pick training
  days`; whether the wordmark stays in tracked capitals.
