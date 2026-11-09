# Where Schedule lives, and how to make the Workout tab stand out

This is a research note written on 2026-11-09. No app code, tests or existing docs were changed.

- **Code read:** worktree `agent-ad6201e0720b771b3`, at the same code as `main` `5b61e69`.
- **Screens looked at:** `build/taste_shots/iPhone-17e/` 01, 02, 04, 06, 10, 11, 15, 17 and 38. `iPhone-17-Pro-Max/` has the same layouts.

## Short answers

**Q1: where should Schedule live?** Split it by job, and do not give it a tab of its own.

- **The plan, the thing you type, stays in Profile › Schedule.** That means editing training days, the reminder switch and the reminder time.
- **The week, the thing that is derived, moves to the top of the Workout landing.** That is a one-line "this week" strip: day markers, "1 of 3", and the next training day.
- **A training reminder opens the Workout tab, not Profile.**

This also removes the derived-on-Profile exception from ADR 0004 instead of adding a new one. It needs a short ADR 0008 that amends 0004 and 0005.

**Q2: how to make the Workout tab stand out.** The logging mechanics are sound: steppers, values filled in from last time, a Recent block, and the map filling on a completed set. The gaps are in feel and hierarchy:

- The app has no haptics at all (`grep HapticFeedback lib/` finds nothing).
- The primary action on the logging screen sits mid-screen, out of thumb reach.
- The landing opens on a library of 11 templates that all look the same, and says nothing about today, this week or the last workout.
- The ready view outlines planned muscles in the colour that means "worked".
- The summary card is "built to be screenshotted" but has no way to share it.

The prioritised list below starts with small polish that needs no decision (haptics, thumb zone, previous values shown in each set row). After that come the hierarchy changes that need a decision (the week strip and repeat-last-workout). The big platform items (Live Activity, widget) come last.

---

## Q1: Where should Schedule live?

### What Schedule is today

- **Built:** `lib/src/ui/schedule_pane.dart`, shown in shot 38.
- **What it shows:**
  - A week summary card: "0 of 3 this week", Mon/Wed/Fri rings, and "3 more to go. Next is Monday".
  - A "Last week" row.
  - The seven training-day chips, with helper copy.
  - Reminders: the switch and the time.
- **Rules from ADR 0005:**
  - The plan is a weekly pattern of days only.
  - It is stored as a dated series that takes effect from Monday.
  - Hits are derived on read.
  - Reminders are opt-in, fixed-schedule, never react to behaviour, and use neutral wording.
- **Rules from ADR 0004:**
  - The week summary is a *named exception* to "derived lives on History, authored lives on Profile".
  - It must never also render on History.
  - Four tabs is the ceiling.
- **Reminder landing:** a training reminder currently opens **Profile › Schedule**. `ReminderTarget.schedule` maps to `ProfileSegment.schedule` in `lib/src/ui/reminder_tap_listener.dart`.

### Criteria

| Criterion | What it implies |
|---|---|
| **Frequency** | Days are set once and changed rarely. The week is *glanced at* every time the user opens the app to train. These are two different use frequencies, which argues for two different homes. |
| **Where the user is when they need it** | At the gym, about to train, they are on the Workout tab. The glance belongs where the Start button is. |
| **HIG tab bars** | "A tab bar lets people navigate between top-level sections of your app" and "it's generally easier to navigate among fewer tabs". Also "Use a tab bar to support navigation, not to provide actions" ([Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)). A Schedule tab would be a fifth top-level section for content that is opened weekly. |
| **HIG settings** | "Put general, infrequently changed settings in your custom settings area." But task-specific options should sit "in the screens they affect, where they're discoverable and convenient" ([Settings](https://developer.apple.com/design/human-interface-guidelines/settings)). The reminder time is a rarely changed setting, so it goes to Profile. The week is context for the task of training, so it goes to Workout. |
| **HIG notifications** | "When people tap a notification or its preview, they expect your app to display related content." Also "Avoid sending a notification that tells people to perform specific tasks within your app" ([Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)). A "training day" reminder is about training, so the related content is the place you start a workout, not a settings form. |
| **HIG navigation** | The [Navigation and search](https://developer.apple.com/design/human-interface-guidelines/navigation-and-search) collection page renders only its index for automated fetch, so there is nothing to quote from it. Tab bars and Settings, above, carry the relevant guidance. |
| **Android / Material 3** | The navigation bar is for "Three to five destinations of equal importance" ([Android Compose navigation bar](https://developer.android.com/develop/ui/compose/components/navigation-bar), which references the [M3 navigation bar](https://m3.material.io/components/navigation-bar/overview)). Schedule is not equal in importance to Workout or History. *Note: the m3.material.io pages render client-side and returned no text, so the Android developer page is the quotable source.* |
| **Nothing derived is stored** | Every option below keeps the week summary computed on read (`thisWeekSummaryProvider` in `lib/src/data/training_plan.dart`). Placement does not affect storage. |
| **ADR 0004** | Four tabs maximum. "Derived lives on History, authored lives on Profile", with the week summary as a named exception that must never also render on History. |
| **ADR 0005** | Days only, never "today's workout". Neutral counts. Reminders never react to behaviour. |

### What production apps do

| App | Where the plan or schedule lives | Where the streak or calendar record lives | Source |
|---|---|---|---|
| Hevy | Routines (the planning unit) live on the **Workout** tab. A day-of-week routine *widget* schedules routines for specific days, and tapping it starts the workout. | **Profile › Calendar**, with the active weekly streak at its top. | [track-workouts](https://www.hevyapp.com/features/track-workouts/), [home-screen-widgets](https://www.hevyapp.com/features/home-screen-widgets/), [gym-consistency](https://www.hevyapp.com/features/gym-consistency/) |
| Strong | Templates are the planning unit. The site lists "Workout Scheduling" but where it sits in the app is unverified. | A calendar home-screen widget shows "monthly workouts and weekly streaks". | [App Store](https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577), [strong.app](https://www.strong.app/) |
| JEFIT | Plans sit on the **Workout** tab: "pick today's day, and tap Start Workout". Training days are picked by weekday, with workout reminders (release 17.2.3). | Calendar on the **Progress** tab. | [log-track](https://www.jefit.com/features/log-track), [App Store](https://apps.apple.com/us/app/jefit-gym-workout-planner/id449810000), [exercise-history](https://www.jefit.com/features/exercise-history) |
| Apple Fitness / Fitness+ | Custom Plans: "Find it all in the Plans page" inside Fitness+. After an activity, "you'll see your next workout or meditation in the Summary tab". Rings can be customised "by the day of the week". | Summary tab (Trends, Awards). | [apple.com/apple-fitness-plus](https://www.apple.com/apple-fitness-plus/), [App Store](https://apps.apple.com/us/app/apple-fitness/id1208224953) |
| Strava | Goals (weekly, monthly, annual) and training plans. | "You can view your Streaks on the Progress tab, found under the You tab." | [Streaks](https://support.strava.com/en-us/articles/15401580-streaks-on-strava), [Goals and training plans](https://support.strava.com/en-us/collections/19668882-goals-and-training-plans) |
| Nike Training Club | Programs, plus "schedule a workout for later". The tab is unverified. | Unverified. | [nike.com/ntc-app](https://www.nike.com/ntc-app), [App Store](https://apps.apple.com/us/app/nike-training-club-wellness/id301521403) |
| Fitbod, Caliber | Unverified. fitbod.me and help.fitbod.me returned 403, and the Caliber App Store ID in the brief returned 404. Caliber's own site lists plans with "Flexible durations to fit your schedule". | Unverified. | [caliberstrong.com/workout-app](https://caliberstrong.com/workout-app/) |

**The pattern.** Two things recur across these apps:

- **The forward-looking plan sits next to the Start action.** Examples are JEFIT's Workout tab, Apple showing the "next workout" on Summary, and Hevy's widget that starts a routine.
- **The backward-looking record (streak, calendar) sits in a profile or progress area.** Examples are Hevy's Profile Calendar and Strava's You › Progress.

None of the apps above gives its schedule a dedicated tab.

### Options weighed

| Option | For | Against | Verdict |
|---|---|---|---|
| **A. Stay in Profile (today)** | Matches "authored lives on Profile". Already built and tested. | The weekly glance is two taps from where the user trains. The derived summary needs a rule exception. A reminder opens a form, not the place to train. | Workable, but it is the weakest fit for the glance. |
| **B. Split: plan on Profile, week strip on the Workout landing** | Puts the glance where the user is. A reminder opens where you train. The plan editor stays with the other settings. Removes ADR 0004's exception (Profile goes back to purely authored data) and moves the derived figure next to Start rather than duplicating it. | Two homes to explain. The strip must never read as "today's workout" (ADR 0005 rule 1). | **Recommended.** |
| C. All of Schedule moves to the Workout tab | One home, next to Start. | The landing gains a form and reminder settings. HIG Settings says rarely changed options belong in a settings area. It also bloats a screen that already scrolls. | No. |
| D. History shows planned versus done | The calendar already exists (`history_calendar_card.dart`). | ADR 0004's condition says the summary must not also render on History, and adding a plan overlay would make History own the plan. History is retrospective and the plan looks forward. Empty "planned" markers on past days drift toward reading as "missed", which conflicts with ADR 0005 rule 5. | No. |
| E. Its own tab | Very visible. | It would be a fifth tab, which ADR 0004 caps. HIG prefers fewer tabs, and M3 asks for "destinations of equal importance". It would be a tab for a set-once feature. | No. |
| F. Settings-style row under Personal | Tidy. | Hides the weekly feedback loop, the very thing ADR 0004 said made Schedule more than a settings page. | No. |

### Recommendation (option B)

**What moves where**

1. **The Workout landing gains a "this week" strip above the search field.** It shows only when no session is open, because an open session *is* the Workout root (ADR 0003).
   - **Content:** the plan's weekday markers with hits filled amber. Amber means trained, which is the colour's existing role. Next to them, "1 of 3 this week · next Wednesday", using ADR 0005's neutral wording.
   - **Derived on read** from `thisWeekSummaryProvider`, with nothing stored.
   - **No plan set:** the strip is either absent or reads one quiet line, "Pick training days". This is a decision for the user.
   - **What it never does:** say what to train, or say "missed".
2. **The Profile › Schedule pane keeps the plan editor and the reminders.**
   - It loses the "Your week" card and the "Last week" row, so Profile goes back to authored data only.
   - "Last week" either moves into the strip as a secondary line or is dropped. This is a decision for the user.
3. **Tapping the strip switches to Profile › Schedule.** This is the same tab-and-segment override `reminder_tap_listener.dart` already uses. A tab switch from L0 is legal under ADR 0003.
4. **A training reminder opens the Workout tab landing, not Profile.** `ReminderTarget.schedule` would become `ReminderTarget.workout`, set through `tabIndexProvider`. Diet reminders still open Profile › Diet, because that is their related content.

**Doc and ADR changes this implies (for whoever builds it)**

- **New ADR 0008, "The week lives on the Workout landing".**
  - Amends ADR 0004: the week-summary exception moves from Profile to the Workout landing, under the same condition (never on History, the summary card or the share card).
  - Restates the placement rule as: "derived lives on History, *except the current week, which lives beside Start*; authored lives on Profile."
  - Amends ADR 0005's consequences to change where the reminder lands.
- **ADR 0004:** add an "Amended by 0008" line to its Status.
- **ADR 0005:** add an "Amended by 0008" line to its Status.
- **`docs/00-build-spec.md` §11:** reword the named exception.
- **`CLAUDE.md`:** reword the matching line, which is its ADR 0004 / 0005 summary.
- **`docs/04`** (Profile flow): remove the week card from the Schedule pane.
- **`docs/02`:** add the strip to the landing.
- **No schema change.** It is a presentation move only.
- **Tests:**
  - Update the reminder-launch tests in `reminder_tap_listener`.
  - Update the Schedule pane tests.
  - Add a landing test asserting the strip never names an exercise or template. That test is the ADR 0005 rule 1 guard.

---

## Q2: Make the Workout tab stand out

### (a) What each app does well on start and logging

These are principles extracted from each app, not looks to copy. Every claim is cited.

| App | Start / landing | Logging | After the workout | Principle to take |
|---|---|---|---|---|
| **Hevy** | "+ Start Empty Workout" at the top, with routines below ([track-workouts](https://www.hevyapp.com/features/track-workouts/)) | A PREVIOUS column shows last time's values inline, and tapping one copies it ([track-exercises](https://www.hevyapp.com/features/track-exercises/)). A lock-screen Live Activity shows the current exercise and next set, and lets you complete a set from it ([live-activity](https://www.hevyapp.com/features/live-activity/)). | The summary shows the PR highlights. Share images come in light, dark and transparent versions ([shareable](https://www.hevyapp.com/features/shareable/)). | The last value sits *in the set row*, not in a separate block. The live workout extends beyond the app. |
| **Strong** | Empty workout or template ([my-first-workout](https://help.strongapp.io/article/229-my-first-workout)) | Complete a set "by hitting the checkbox". Live Activity and Dynamic Island support, for rest timers only (6.5.0, [App Store](https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577)). | Share through the system share sheet ([share](https://help.strongapp.io/article/109-share-workout-or-template)) | One gesture marks a set done. Lean on system surfaces such as the share sheet. |
| **JEFIT** | Pick today's day of your plan, then Start ([log-track](https://www.jefit.com/features/log-track)) | Every set is filled in with last time's values, and "most sets take a single tap to confirm". The set count shows on the lock screen ([App Store](https://apps.apple.com/us/app/jefit-gym-workout-planner/id449810000)). | The summary includes a body map of trained muscles, plus new records ([log-track](https://www.jefit.com/features/log-track)) | Filling in from last time plus a single tap to confirm is the speed benchmark. The body map is a summary moment. |
| **Apple Fitness / Workout** | The next workout appears on Summary after an activity ([apple.com](https://www.apple.com/apple-fitness-plus/)) | HIG: "use large font sizes, high-contrast colors"; "Avoid distracting people from a workout with information that's not relevant" ([Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts)) | "A summary screen confirms that a workout is finished and displays the recorded information" ([Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts)) | Mid-set: legible, few elements. The end: a clear confirmation. |
| **Strava** | Lock-screen widgets that "take you directly to" a tab (v480, [App Store](https://apps.apple.com/us/app/strava-run-bike-walk/id426826309)) | Not applicable (Strava does not log sets live) | Strength shareables: "Muscle Map (Front + Back)" and stats plus muscle map, including transparent variants ([strength-training](https://support.strava.com/en-us/articles/15401547-strength-training)) | The muscle map is the share image. TurtleLift already owns this asset. |
| **Gentler Streak** (ADA 2024 winner) | Activity Path: readiness, a 10-day view and a 30-day view ([gentlerstories.com](https://gentlerstories.com/gentlerstreak/)) | Not applicable | The jury praised its Monthly Summary as "less about hard comparisons and more about progress" ([ADA 2024](https://developer.apple.com/design/awards/2024/)). "Taking a break never means starting over." | Calm, non-punitive progress framing. This matches "steady, exact, quietly warm". |
| **Any Distance** (ADA 2023 winner) | Not applicable | "takes full advantage of Live Activities" | "workout stats in a variety of eye-popping and easily shareable formats" ([ADA 2023](https://developer.apple.com/design/awards/2023/)) | Design awards reward the share artefact and the system surfaces. |
| **Ladder** | Programming "looks like a week again, not a video library" (4.13.1, [App Store](https://apps.apple.com/us/app/ladder-strength-training-plans/id1502936453)) | An option to flash the screen when a movement is about to end | Not applicable | The week, not the library, frames the landing. Ladder's own release notes make this point about their landing. |

Fitbod, Caliber and Nike Training Club logging screens could not be verified from primary sources: the Fitbod site was blocked, the Caliber listing returned 404, and NTC's What's New is generic. They are omitted rather than guessed.

### (b) Gap analysis of TurtleLift's Workout screens

**Landing (shots 01, 02; `lib/src/ui/workout_root.dart`)**

1. **The hierarchy is library-first.** It runs: search, "My templates", then 11 identical "Ready-made" tiles. Nothing says what this week looks like or what you did last time, and Hevy, JEFIT and Ladder all frame the start with the user's own context. The biggest element is the "Start workout" bar, which is correct, but everything above it has equal weight.
2. **The landing reads the same on day 1 and day 100.** A returning lifter scrolls past the same 11 ready-made tiles every time, and nothing on the screen changes with their history.
3. **"Manage templates" is at the very bottom.** That placement is fine: ADR 0004 says this route is now convenience, not load-bearing.

**Ready view (shot 04; `session_overview_body.dart`, `session_body_map.dart`)**

4. **Planned muscles are outlined in amber.** Amber's role is "trained / active / PB", so before a single set the map already reads as partly done. Planned muscles want a neutral or steel outline, with amber arriving only when a muscle is worked.
5. **"6 exercises planned" shows no names.** The lower half of the screen is empty. A short list of the six exercise names would make the start feel concrete.
6. **"Discard workout" has nearly the same visual weight as "Start logging"** and sits right under it.

**Live session (shot 15)**

7. **The header reads "Name this workout" in grey placeholder text.** It looks unfinished. The spec already derives a resolved title, so the header should show that title, with renaming as an affordance.
8. **The Up next card and the 0:24 display-only clock are good.** The map is smaller here than on the ready view, just when it starts to carry meaning.

**Set logging (shots 10, 11; `set_logging_screen.dart`, `set_row.dart`, `stepper_field.dart`)**

9. **No haptics anywhere in the app.**
   - A set tick is the single most repeated action in the app, and it is silent.
   - HIG: "Notification haptics provide feedback about the outcome of a task", and "prefer playing short haptics that complement discrete events" ([Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)).
   - Android: haptics "confirm a state change … following a user action" ([haptics principles](https://developer.android.com/develop/ui/views/haptics/haptics-principles)).
10. **The primary action, "Mark exercise done", sits at about 43% of screen height.** The bottom 40% of the screen is empty. With a phone held in one hand between sets, the thumb lives at the bottom.
11. **Previous values sit in a separate "Recent" block below the button,** as in "5 Oct · 60kg × 8 · 62.5kg × 6". Rows are filled in from last time, which is good, but once you change a value you lose sight of what you are comparing against. Hevy and JEFIT put the comparison in the row.
12. **A completed set only fills its checkbox amber.** The row keeps its full-contrast steppers, so done and to-do rows look nearly the same at a glance. There is no in-the-moment PB mark either: `set_logging_screen.dart` has no PB reference.
13. **The ± controls are glyph buttons placed at a uniform rhythm,** which is fine. The value boxes fit their text (`_fittedSize`), and the value ignores the system text size by design.

**Summary (shot 17; `session_summary_screen.dart`, `finish_celebration.dart`)**

14. **The card is "built to be screenshotted" but has no share action.** `share_plus` is already a dependency, used only by Export. Strava and Any Distance both treat the share image as the product moment.
15. **The card's stat row is generic** (Sets, Exercises, Day streak, kcal), and "3 kcal" with an info icon weakens the screenshot.
    - The "TURTLELIFT" wordmark is tracked capitals. The taste pass rule says "never tracked capitals". A wordmark may be a deliberate exception, but if so that should be recorded.
    - The previous audit (`docs/research/unslop-audit.md`) already flagged "no moment" on this card.

**System surfaces**

16. **No Live Activity, no widget.** An open session already has a defined start and is gated to under 6 hours, which fits HIG's "tasks and events that have a defined beginning and end … that don't exceed eight hours" ([Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)).

### (c) Prioritised improvements

Effort: **S** is under a day, **M** is one to three days, **L** is a week or more, or native code. "Decision" means it adds behaviour or changes a rule, so the user must say yes. "Polish" means it fits existing rules.

| # | What | Why (principle + source) | Screen / file | Effort | Decision? |
|---|---|---|---|---|---|
| 1 | **Haptics with a fixed vocabulary.** Selection click on each ± step. Medium impact on a set tick. Success notification on Mark exercise done and on Finish. Nothing on scroll or navigation. Use Flutter's built-in `HapticFeedback`, so no plugin is needed. | HIG "Use haptics consistently … clear, causal relationship" and "Avoid overusing haptics" ([Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)). Android: "More important events … should be stronger" ([haptics principles](https://developer.android.com/develop/ui/views/haptics/haptics-principles)). | `stepper_field.dart`, `set_row.dart`, `set_logging_screen.dart`, `session_actions.dart` | S | Polish |
| 2 | **Pin the logging screen's primary action to the bottom thumb zone.** Mark exercise done goes into a bottom bar above the safe area. Add set and Recent stay in the scroll. | HIG Workouts: "Provide workout controls that are easy to find and tap" ([Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts)). The landing already pins Start this way. | `set_logging_screen.dart` | S | Polish |
| 3 | **Show last time's value inside each set row.** A muted line under each set reads "last 62.5 × 6", derived on read from the same query as Recent. Tapping it copies the value in. The Recent block stays for multi-session context. | Hevy's PREVIOUS column ([track-exercises](https://www.hevyapp.com/features/track-exercises/)). JEFIT fills every set in from last time ([exercise-history](https://www.jefit.com/features/exercise-history)). It keeps the comparison in sight after you edit. | `set_row.dart`, `set_logging_screen.dart` | M | Polish |
| 4 | **A "this week" strip and a "last workout" line at the top of the landing.** The week strip is from Q1. The last-workout line reads something like "Thu · Push day · 14 sets". It is derived, never suggests what to do next, and tapping it opens that session's detail. | Ladder: the week, "not a video library" ([App Store](https://apps.apple.com/us/app/ladder-strength-training-plans/id1502936453)). Apple shows the next workout on Summary ([apple.com](https://www.apple.com/apple-fitness-plus/)). It answers "where am I" before "what do I pick". | `workout_root.dart` (`WorkoutLandingBody`) | M | **Decision** (ADR 0008 from Q1) |
| 5 | **A done set looks done.** On tick, the steppers fade to the muted colour, the number holds at full contrast and the check fills amber, with a short (~150 ms) ease. If the set is a PB it shows the word "PB" in amber, the single PB mark from `00` §12, at the moment it happens. | HIG: match a haptic's intensity "with the intensity and sharpness of the animation it accompanies" ([Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)). Hevy surfaces PRs at the moment ([track-workouts](https://www.hevyapp.com/features/track-workouts/)). | `set_row.dart`, `set_logging_screen.dart` | M | **Decision** on the live PB (the assisted PB is inverted, so it must use the existing derived helper) |
| 6 | **Make the body map the hero on the session screens.** Planned muscles get a steel or neutral outline, not amber. When a muscle is first worked, its segment fills with a ~300 ms ease on return to the overview. The map gets more height on the live screen. | JEFIT and Strava both make the muscle map the summary visual ([log-track](https://www.jefit.com/features/log-track), [strength-training](https://support.strava.com/en-us/articles/15401547-strength-training)). The unslop audit names the map as one of two moments. Amber means worked, so it should not appear before a set. | `session_body_map.dart`, `body_diagram.dart`, `session_overview_body.dart` | M | **Decision** (a colour-role change for "planned") |
| 7 | **Live session header shows the resolved title, not "Name this workout".** Derived on read, with a pencil affordance to rename. | Placeholder text in a pinned header reads unfinished. The resolved title is already a derived value in `00` §2. | `session_header.dart` | S | Polish |
| 8 | **The ready view lists what is planned.** Up to six exercise names under the map. "Discard workout" moves to the header's overflow or becomes a smaller ghost button. | HIG Workouts: "Avoid distracting people … with information that's not relevant". The plan *is* relevant at the start. It also fills the empty lower half of the screen. | `session_overview_body.dart` | S | Polish |
| 9 | **Share the summary card as an image.** Render the existing `_ShareCard` to PNG (`RepaintBoundary` + `toImage`) and pass it to `share_plus`, which already ships a `Package.swift`. At the same time: replace "kcal" in the stat row with the PB count when there are PBs, and record or drop the tracked-caps wordmark. | Strava strength shareables ([strength-training](https://support.strava.com/en-us/articles/15401547-strength-training)). Any Distance won an ADA for shareable formats ([ADA 2023](https://developer.apple.com/design/awards/2023/)). Strong uses the system share sheet ([share](https://help.strongapp.io/article/109-share-workout-or-template)). | `session_summary_screen.dart` | M | **Decision** (`00` §13 says "no social features". A share sheet is not a feed, but the user should confirm.) |
| 10 | **Repeat a past workout.** A "Do again" action on the last-workout line and on a History session detail copies that session's exercise list into a new session, exactly like starting a template. | Hevy and JEFIT both start from saved routines ([track-workouts](https://www.hevyapp.com/features/track-workouts/), [log-track](https://www.jefit.com/features/log-track)). Strava v488: "Copy a past session" ([App Store](https://apps.apple.com/us/app/strava-run-bike-walk/id426826309)). Choosing from your own history is user-initiated, not a suggestion. | `workout_root.dart`, `history_session_detail_screen.dart`, `session_entry.dart` | M | **Decision** (it must stay clear of the "no today's workout suggestion" rule) |
| 11 | **Let the library recede for returning users.** Once a user has their own templates or 3 or more sessions, the "Ready-made" grid collapses into one "Browse ready-made" row, or a compact list. My templates stays as tiles. | Ladder: a landing that looked like "a video library" was the problem they fixed (4.13.1). A returning lifter should see their own context first. | `workout_root.dart` | M | **Decision** |
| 12 | **A "Recent" group at the top of the exercise picker.** It lists exercises logged in the last few sessions, ordered by recency and derived on read. The picker already shows "Last 62.5kg × 6". | Retrieval over search for the habitual lifter. It cuts taps before the first set, which was ADR 0006's stated goal. | `exercise_picker_sheet.dart` | S | Polish |
| 13 | **Respect Reduce Motion everywhere the moves above add motion.** That covers the map fill, the set-row settle and the finish celebration: honour `MediaQuery.disableAnimations` and fall back to a crossfade. | HIG motion and accessibility. `finish_celebration.dart` already runs an 850 ms sequence. | `finish_celebration.dart`, plus items 5 and 6 | S | Polish |
| 14 | **A Live Activity for an open session.** It shows the current exercise, "sets done", and the display-only elapsed clock using a system timer, with nothing stored. Tapping it opens the session. It ends on Finish or Discard. Android equivalent: an ongoing notification. | HIG: "Offer Live Activities for tasks and events that have a defined beginning and end … don't exceed eight hours". Workouts are its named example ([Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)). Hevy and JEFIT ship lock-screen workout status. | New iOS widget extension (Swift). The Flutter plugin must ship `Package.swift`. | L | **Decision** (a new platform surface. On Android it is a notification, which ADR 0005 limits. No rest timer on it.) |
| 15 | **A home-screen / lock-screen widget.** It shows the "this week" strip and a Start tap that opens the Workout landing. | HIG Widgets: "Ensure that a widget interaction opens your app at the right location" ([Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)). Hevy and Strong ship calendar and streak widgets. | New widget extension | L | **Decision** |

**Order of work.** Items 1–3, 7, 8, 12 and 13 are polish and can ship as one taste pass with no decisions. Item 4 waits on the Q1 decision. Items 5, 6, 9, 10 and 11 each need a yes or no. Items 14 and 15 need native work and a scope call.

### Out of scope for V1, for later

These conflict with `CLAUDE.md` "Out of scope for V1" or `00` §13, so they are listed only so they are not lost.

- **An automatic rest timer after a set tick.** Hevy, Strong and JEFIT all have one ([live-activity](https://www.hevyapp.com/features/live-activity/), [rest-timer](https://help.strongapp.io/article/231-rest-timer), [log-track](https://www.jefit.com/features/log-track)). V1 says no rest timer.
- **Apple Watch logging** (Hevy, Strong). V1 says no wearables.
- **AI-generated or adaptive workouts** ([Fitbod listing](https://apps.apple.com/us/app/fitbod-gym-fitness-planner/id1041517543)), and Hevy's "send to ChatGPT/Claude". V1 says no AI.
- **Workout ordinal milestones** ("472nd"), and badges such as JEFIT's day-7/14/21 badges. V1 says no achievements.
- **Workout duration on the summary or share card.** V1 says no stored duration, and the clock is display-only.
- **Friends feeds, live workout status for friends, PR notifications to others** (Caliber community, Apple's Sharing tab). V1 says no social features.
- **Scheduling a specific workout on a specific day,** such as Hevy's day-of-week routine widget or JEFIT's "pick today's day". This is a split, which ADR 0005 rule 1 rules out.
- **Readiness or recovery-based suggestions** (Gentler Streak, Harvee). V1 says no suggestions and no wearables.
- **Plate and warm-up calculators** (Hevy, Strong PRO). These are not listed as out of scope, but they are new features beyond V1's brief. Park them for a V2 discussion.

---

## Sources

**Apple HIG.** The text was read through the HIG JSON data endpoint, because the HTML pages render client-side.
- Tab bars: https://developer.apple.com/design/human-interface-guidelines/tab-bars
- Navigation and search: https://developer.apple.com/design/human-interface-guidelines/navigation-and-search (index only, nothing quoted)
- Notifications: https://developer.apple.com/design/human-interface-guidelines/notifications
- Settings: https://developer.apple.com/design/human-interface-guidelines/settings
- Workouts: https://developer.apple.com/design/human-interface-guidelines/workouts
- Live Activities: https://developer.apple.com/design/human-interface-guidelines/live-activities
- Playing haptics: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- Widgets: https://developer.apple.com/design/human-interface-guidelines/widgets

**Material and Android**
- M3 navigation bar: https://m3.material.io/components/navigation-bar/overview (no text returned)
- Compose navigation bar: https://developer.android.com/develop/ui/compose/components/navigation-bar
- Haptics principles: https://developer.android.com/develop/ui/views/haptics/haptics-principles

**Apps**
- Hevy:
  - https://apps.apple.com/us/app/hevy-workout-tracker-gym-log/id1458862350
  - https://www.hevyapp.com/features/track-workouts/
  - https://www.hevyapp.com/features/track-exercises/
  - https://www.hevyapp.com/features/live-activity/
  - https://www.hevyapp.com/features/home-screen-widgets/
  - https://www.hevyapp.com/features/gym-consistency/
  - https://www.hevyapp.com/features/shareable/
- Strong:
  - https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577
  - https://www.strong.app/
  - https://help.strongapp.io/article/229-my-first-workout
  - https://help.strongapp.io/article/231-rest-timer
  - https://help.strongapp.io/article/169-plate-calculator
  - https://help.strongapp.io/article/171-warm-up-calculator
  - https://help.strongapp.io/article/109-share-workout-or-template
- JEFIT:
  - https://apps.apple.com/us/app/jefit-gym-workout-planner/id449810000
  - https://www.jefit.com/features
  - https://www.jefit.com/features/log-track
  - https://www.jefit.com/features/exercise-history
  - https://www.jefit.com/watch
- Fitbod: https://apps.apple.com/us/app/fitbod-gym-fitness-planner/id1041517543 (fitbod.me and help.fitbod.me returned 403)
- Apple Fitness:
  - https://apps.apple.com/us/app/apple-fitness/id1208224953
  - https://www.apple.com/apple-fitness-plus/
- Strava:
  - https://apps.apple.com/us/app/strava-run-bike-walk/id426826309
  - https://support.strava.com/en-us/articles/15401580-streaks-on-strava
  - https://support.strava.com/en-us/articles/15401547-strength-training
  - https://support.strava.com/en-us/collections/19668882-goals-and-training-plans
- Nike Training Club:
  - https://apps.apple.com/us/app/nike-training-club-wellness/id301521403
  - https://www.nike.com/ntc-app
- Caliber: https://caliberstrong.com/workout-app/ (the App Store ID id1450222917 returned 404; the site links id1482405410, which was not fetched)
- Gentler Streak: https://gentlerstories.com/gentlerstreak/
- Ladder:
  - https://apps.apple.com/us/app/ladder-strength-training-plans/id1502936453
  - https://www.joinladder.com/
- Future: https://www.future.co/
- Apple Design Awards:
  - https://developer.apple.com/design/awards/2023/
  - https://developer.apple.com/design/awards/2024/
  - https://developer.apple.com/design/awards/2025/

**Repo**
- `docs/adr/0003`–`0007`
- `docs/00-build-spec.md` §11–13
- `docs/research/unslop-audit.md`
- `lib/src/ui/workout_root.dart`, `reminder_tap_listener.dart`, `schedule_pane.dart`, `session_summary_screen.dart`, `stepper_field.dart`
- `lib/src/data/training_plan.dart`
- `build/taste_shots/iPhone-17e/`

**Not verified, so not claimed:**
- Fitbod's in-app schedule and logging screens.
- Caliber's logging screen.
- Where NTC's schedule lives.
- Haptics in any competitor app. None of their pages mention it.
