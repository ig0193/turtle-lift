# 15. The Schedule is removed, and Diet is a log, not a plan

Date: 2026-11-15

## Status

> **Amended by [ADR 0016](0016-you-tab-and-diet-tab.md):** Profile is now the You
> tab; Diet is its own tab, so "Profile is Personal | Diet" below no longer
> holds.

Accepted. The user asked for both changes directly, and chose the real log
over a UI-only change when asked how far "log, not plan" should go.

**Supersedes ADR 0005** (the Schedule, its training-day reminders, the week
summary). **Amends ADR 0004** (Profile has two segments, not three), **ADR 0007**
(Diet is a log; the weekly plan, the eaten tick and the morning summary go) and
**ADR 0008** (the week strip leaves the Workout landing; the Last workout line
stays). Builds on ADR 0014 (reminder honesty, pinned segment control, export).

## Context

The Schedule asked the user to say which weekdays they train on, then measured
each week against that pattern. Diet asked them to plan a week of protein once,
repeated it every week, and let them tick a meal as eaten. Both are planning
features. The user does not want the app to plan for them: they want a record of
what they did (workouts, already) and what they ate.

Diet being a plan also made it behave oddly as a record: adding a food on a
Sunday added it to every Sunday, an empty log opened on a first-time screen
that said "Plan your week's protein", and "eaten" was a second step on top of
"added".

## Decision

1. **The Schedule is removed completely.** No Profile › Schedule segment, no
   training-day plan, no week summary, no week strip on the Workout landing, no
   training-day reminder, no widget week. The Workout landing keeps its **Last
   workout** line; the home-screen widget shows that line and nothing else.
   Profile is **Personal | Diet**.
2. **Diet is a dated log.** One row per food per meal slot per calendar day
   (`DietLogEntries`: `date`, `slot`, `foodId`, `servingsHalves`, `position`).
   A row belongs to its date and repeats nowhere. Adding or changing a food
   changes that day and no other.
3. **A food in the log has been eaten.** There is no eaten tick, no "planned"
   versus "eaten" pair of figures and no two-layer bar. The day card says
   "N g logged" or "N of T g logged", with "N g to go" while under the target.
4. **Today and earlier only.** A day after today cannot be selected in the week
   strip and the store rejects a future date, reading its own clock at write
   time (the `planTodayProvider` cache can lag across midnight). Every past day
   is editable (the strip showed only this week at first; ADR 0017 adds a date
   picker that reaches the rest).
5. **Diet opens on the day view, always.** The first-time state, "Plan Monday"
   and the serving sheet's "Repeat on" chips are gone. An empty day already says
   what to do ("Nothing logged for Sunday", four empty slots, "+ Add food").
6. **Diet reminders are nudges to log.** One weekly reminder per meal slot the
   user switches on ("Log your lunch", body "Add what you ate to today's Diet
   log."). There is no plan to read a meal from, so the morning summary is
   removed, and what the log holds never reaches a reminder. The master switch,
   explain-first sheet, honest "Off in Settings" state and times are unchanged.
7. **Schema version 10** (CLAUDE.md records the current version). Step 10 creates `diet_log_entries`; **keeps what the user did** by turning
   each ticked meal into the foods the plan in force that week had in that slot
   on that weekday, logged on the tick's date; then drops `meal_ticks`,
   `diet_plan_items`, `diet_plan_versions` and `training_plan_entries`. The
   plan itself and the training days are not kept: they were intentions, not
   records. Steps 4 and 6 no longer create tables that step 10 would drop.
   Columns cannot be dropped, so `reminder_prefs.schedule_on`,
   `schedule_minute`, `summary_on` and `summary_minute` stay, unwritten and
   unread.
8. **Retired notification ids are cancelled** (`kRetiredReminderIds`: 100-106
   training, 200-206 summaries) every time the diet reminders reschedule, so an
   upgrade leaves nothing pending for a feature that no longer exists. The
   `schedule` payload string still routes to the Workout tab, because a
   notification already delivered can sit on the shelf for weeks.
9. **Export is format 2.** No `schedule` key; `diet` is `{ proteinTargetG, log }`
   with one row per food (`date`, `slot`, `foodId`, `name`, `servings`);
   `reminders` has only `diet`.
10. **`training_plan.dart` is gone, and its clock is not.** `planTodayProvider`,
    `planClockProvider`, `startOfWeek` and `kWeekdayCount` live in
    `lib/src/data/today.dart`, because History, Muscles and Diet all need
    "today" and the week.

## Consequences

- **Scope line.** CLAUDE.md says "no food-diary tracking". This is a protein log
  from the fixed, reviewed food list, with servings in halves: still no
  calories, carbs or fat, no free-form entry, no custom foods. The line is
  reworded rather than deleted so the boundary stays visible. Anything wider
  (custom foods, macros, a free-text diary) is a new decision.
- **The data migration is the one step in the app that moves rows**, so it has
  its own test against a real version-9 database
  (`test/app_database_migration_test.dart`), and no later step may be numbered
  below 10.
- **Streaks and week summaries are gone**, not hidden: there is nothing left to
  turn back on. A training plan can come back as a new decision; it would start
  from an empty table.
- **Prototypes** (`prototypes/screens.html`, `prototypes/diet.html`) still draw
  the Schedule and the plan. They are a visual reference, and where they differ
  on a rule this ADR wins.
- **Maestro flows** for the Schedule and the training reminder are deleted; the
  Diet flow is now a log flow. They run on iOS simulators and were updated
  without being run here.
