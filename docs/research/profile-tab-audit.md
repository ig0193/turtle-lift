# Profile tab audit

Date: 2026-11-10. Branch: detached at `origin/taste-pass-production-polish`
(a7b6fa1, which includes the History work). Builds on ADRs 0004, 0005, 0007,
0008 and 0013. The build that follows this audit is logged in
`docs/research/profile-progress.md`, and its decisions are recorded in ADR 0014.

## Method

- **Used it.** The seeded debug build ran on the iPhone 17e simulator, with a
  spot check on the 17 Pro Max and a run at the largest text size
  (`accessibility-extra-extra-extra-large`, which the app clamps to 1.3x). I
  covered Personal (templates row, Personal details: gender, bodyweight, the
  weight log), Schedule (days, Remind me, time), Diet (week strip, day card,
  slot cards, eaten ticks, the target screen, meal reminders), Export and
  Delete all data. I read Maestro accessibility dumps for the VoiceOver labels.
- **Read the code** for every screen in the tab and its stores:
  `profile_root.dart`, `profile_screen.dart`, `personal_details_screen.dart`,
  `schedule_pane.dart`, `reminder_controls.dart`, `diet_pane.dart`,
  `protein_target_screen.dart`, `diet_reminders_screen.dart`,
  `data_screens.dart`, `data_export.dart`, `personal_details_store.dart`,
  `training_plan.dart` and `reminder_prefs.dart`.
- **Compared** eight apps from their primary sources (help centres, official
  pages, App Store listings). See [Competitors](#competitors-8).

Baseline: `flutter test` had 1523 tests, all green.

## Verdict

Profile is honest and tidy. Nothing derived from sessions leaks onto it, the
bodyweight series is immutable for a good reason, reminders follow ADR 0005,
and Delete all data really does wipe everything. It is not production quality
yet, for three reasons:

1. **It accepts bad data and gives no feedback.** A 0.5 kg bodyweight is
   recorded without complaint. It then drives a 1 g protein suggestion and a
   near-zero calorie figure, and the series rule means it can never be removed
   after midnight. An empty or zero entry fails silently.
2. **Some controls say "on" when nothing will happen.** Remind me can be on
   with no training days. The Diet Reminders row says "On" with no meal
   chosen, and "3 a day" after iOS notifications were turned off. The off note
   says "Turn them on in Settings" but gives no way to get there.
3. **It shows less than the best apps do about the data it already holds.**
   The rows never show current values ("Weight log · gender"). The weight log
   is a list of ISO dates with no trend. Export is JSON only, and leaves out
   your reminder settings and, in the counts, your schedule. There is no
   version, privacy note or licence page anywhere in the app.

## Bugs

| # | Where | What | Severity |
|---|---|---|---|
| B1 | `personal_details_screen.dart:152-155`, formatter `:251` | Bodyweight accepts 0.1 to 999.9 kg. Recording 0.5 kg succeeds; the protein suggestion becomes 1 g (`protein_target_screen.dart:146`) and calories go to near zero for the day. Empty, zero or unparsable input is dropped silently: nothing happens and nothing says why. | High (bad data, permanent after midnight) |
| B2 | `personal_details_screen.dart:336` | Weight log rows read "from 2026-11-10", an ISO date. ADR 0013 made day-month-year the one format (`date_labels.dart`). | Medium |
| B3 | `personal_details_screen.dart:46-48, 152-159` | There is no confirmation after Record (the field clears, nothing else). Nothing says that today's entry can still be corrected (a second Record today replaces it, `appendBodyweightEntry` upserts on the date), or that after today it is fixed. | Medium |
| B4 | `profile_root.dart:87-100` | The segmented control scrolls away with the pane. On the long Diet pane, after you come back from a pushed screen (the target or meal reminders), the control is off screen and you must scroll up to switch segment. The Maestro run hit exactly this. | Medium |
| B5 | `schedule_pane.dart:170-175`, `training_plan.dart:259-271`, `reminder_prefs.dart:239-242` | Lost update: `_toggleDay` reads the plan, then `save` awaits the database before it updates state. A second quick tap reads the old set and overwrites the first, so one day is lost. `ReminderPrefsLog.save` has the same shape. | Medium |
| B6 | `schedule_pane.dart:214-228` | Remind me can be on with no training days. Nothing is scheduled, and nothing says so. | Medium |
| B7 | `diet_pane.dart:96-101` | The Reminders row says "On" when the master switch is on but no reminder is chosen (nothing will fire), and "N a day" after notifications were turned off in iOS Settings. The meal slot header still shows its reminder time in that case too (`diet_pane.dart:272-278`). | Medium |
| B8 | `diet_reminders_screen.dart:205, 227` | Each of the five time rows is announced "Time, 8:00 AM", with no meal named. In a row of five, VoiceOver cannot tell them apart. The disabled subtitle "Turn on reminders to set times" repeats five times. | Medium (a11y) |
| B9 | `data_screens.dart:79-84, 244-251` | Export is disabled ("Nothing to export yet. Log a workout first.") when the user has entered only a schedule, a reminder setting or a body diagram choice. Those are entered data, and they are in the file. The counts card never shows the schedule. | Low |
| B10 | `data_export.dart` | "Export everything" leaves out the reminder preferences (the switches and times the user set). They are entered data, so they belong in the file. | Low |
| B11 | `reminder_controls.dart:19-20` | "Notifications are off for TurtleLift. Turn them on in Settings." gives no route to Settings. iOS allows a deep link to the app's own settings page (`UIApplication.openSettingsURLString`). | Low |
| B12 | `profile_screen.dart:96, 154-159` | The Personal details row is a fixed "Weight log · gender". It never shows the weight in effect or the diagram chosen, so you have to open the screen to check either. | Low |
| B13 | `protein_target_screen.dart:146-153`; no code on `personal_details_screen.dart` | When the bodyweight changes after a target is set, nothing ever says the suggestion moved. The new suggestion appears only if you open the target screen, and even then it does not say which weigh-in it comes from. | Low |

Checked and found correct: a gender write does not clear the protein target
(`insertOnConflictUpdate` updates only present columns; a regression test now
guards it). The bodyweight resolver picks the entry in effect on a session's
date. The 1.6 g/kg suggestion is clamped to the target's bounds. Delete all
data empties every table and cancels every notification. The largest text
size holds on every Profile screen (1.3x clamp), with no clipping.

## Findings by screen

**Personal pane.** There are four rows and a lot of empty space. The rows
carry no current values (B12). There is no About section anywhere in the app:
no version, nothing that says the data stays on the phone (the app's biggest
privacy promise), and no open-source licence page. Flutter apps ship many
third-party licences, and `showLicensePage` exists for this.

**Personal details.** The gender chips are good: three options, a caption
saying it changes nothing else, amber outline for "selected". Bodyweight has
B1 to B3. The log is a plain list with no shape. Every competitor that logs
weight shows a graph or a trend next to the raw entries [ST1][M3][P3]. The
calorie explainer is good and stays.

**Schedule.** It is clean. The day chips announce full weekday names. B5 and
B6 apply. The off note has no route to Settings (B11).

**Diet.** The day view is good: the planned/eaten bar, ticks, "Repeat on" in
the serving sheet. B4, B7 and B13 apply. Meal reminders: B8.

**Export.** The share sheet, status line and counts work, with B9 and B10.
JSON is right for completeness, but nobody opens JSON in a spreadsheet. Hevy,
Strong and MyFitnessPal all export CSV [H1][ST4][P2].

**Delete all data.** It has a separate screen, counts, a confirm dialog in
the destructive colour, a one-transaction wipe and a reboot. It says "Export
first if you want to keep a copy", but has no Export button. Strava offers
the archive inside its deletion flow [V4]. It does not say what is untouched:
files you already exported or shared stay where you put them [F3].

## Competitors (8)

Primary sources only. Most help centres return 403 to a direct fetch; "(S)"
marks a claim taken from the search engine's indexed copy of that primary
URL. "nv" = not verified. Behaviour only: no look, name or artwork is taken.

| App | Units | Bodyweight log | Protein target | Reminders | Export / import | Delete / reset | Weekly goal |
|---|---|---|---|---|---|---|---|
| **Hevy** | One global setting for weight, distance and measurements; per-exercise override [H2](S) | Profile › Measures, "+" adds a dated entry; Pro adds body fat and photos [H3](S) | none | Rest timer, live PR, Live Activity; no workout reminder found (nv) | Export Workouts *or* Measurements as CSV; import only an unedited Strong CSV, merged by date [H1](S) | Account delete requires typing the username [H4](S) | nv |
| **Strong** | Imperial, metric or mixed [ST4](S) | Measurements: "+" adds an entry, tap for history, swipe to delete; Health sync [ST1] | none (calories via Health) [ST1] | nv | Settings › Export Strong Data as CSV [ST4](S) | nv | Workouts-per-week widget with an editable goal [ST3](S) |
| **Fitbod** | Preferences › Units, per-exercise override; warns about rounding when switching [F1](S) | Body composition (nv) | none | Workout previews and goal reminders separate from marketing [F2](S) | No self-serve export; by email [F3](S) | Settings › Help › Permanently Delete; says Apple Health copies remain [F3](S) | nv |
| **JEFIT** | lb/kg display switch [J3](S) | Profile › Body stats › Update stats; body tab [J1](S) | none | nv | CSV (vendor marketing, nv) [J4](S) | Deactivate needs the password; separate "Clear online data" [J2](S) | nv |
| **MacroFactor** | nv | Scale weight log: tap to edit or delete; trend weight shown separately [M3] | Coached protein from lean mass and level, applied only at the weekly check-in, which the user approves or dismisses [M1] | nv | Granular or quick export, chosen datasets and period [M2] | Bulk or granular delete; recommends fixing entries first [M4] | nv |
| **MyFitnessPal** | nv | One weight a day; Progress card with a time frame [P3](S) | Percent steps (free) or grams (premium) [P1](S) | Any number of logging reminders, each with its own time, pausable [P4](S) | Premium: CSVs by email [P2](S) | More › Help › Delete account [P5](S) | nv |
| **Apple Fitness / Health** | Unit per data type [A2](S) | Add Data takes date, time, value; Show All Data; swipe to delete [A2](S) | n/a | Monday summary with suggested goals [A1](S) | Export All Health Data (XML) [A3](S) | Per entry and per type [A2](S) | Ring goals scheduled by weekday [A1](S) |
| **Strava** | One imperial/metric setting [V2](S) | n/a | n/a | nv | Request an archive by email [V3](S) | Email, password, then a link; offers the archive inside deletion [V4](S) | Weekly/monthly/annual goals by metric [V1](S) |

**Principles to take**
1. **Validate at entry, explain inline.** Every weight entry is a dated value
   with a plausible range. A wrong value should be refused with a reason, not
   recorded and then left stuck [M3][A2].
2. **Show a trend next to the raw entries** [M3][P3][ST1].
3. **A derived target changes at a visible moment and never silently.**
   MacroFactor recomputes protein but applies it only at a check-in the user
   approves [M1]. TurtleLift stores the number the user accepted. It should
   say when the suggestion has moved, at the moment of the weigh-in, and let
   the user choose.
4. **Reminders are individually toggled items, gated on permission, and say
   when they cannot fire** [P4][F2].
5. **Export is complete and readable without the app**: per-domain or
   spreadsheet-friendly files, with the unit labelled [H1][M2][P2].
6. **Delete-all offers the export inside the flow and says what it does not
   touch** [V4][F3].
7. **Show the current value on the row**, so the screen is a glance, not a
   hunt (Hevy, Strong and MacroFactor all list current stats on their profile
   or measurements screens [H3][ST1][M3]).

**Sources**
- [H1] https://help.hevyapp.com/hc/en-us/articles/43708290987415-Exporting-Your-Data-from-Hevy
- [H2] https://help.hevyapp.com/hc/en-us/articles/34953292892823-How-to-change-the-measurement-units-Single-exercise-or-all-exercises
- [H3] https://help.hevyapp.com/hc/en-us/articles/35385479603479-Body-Composition-Tracking-Measurements-and-Progress-Photos
- [H4] https://help.hevyapp.com/hc/en-us/articles/38030200802583-How-to-Delete-Comments-Sets-Workouts-Routines-Your-Hevy-Account
- [ST1] https://help.strongapp.io/article/238-add-measurements
- [ST3] https://help.strongapp.io/article/239-profile-widgets
- [ST4] https://www.strong.app/
- [F1] https://help.fitbod.me/hc/en-us/articles/23560953306263-Changing-Units-Imperial-Metric
- [F2] https://help.fitbod.me/hc/en-us/articles/11884915047575-Notification-Settings-Marketing-Communications
- [F3] https://help.fitbod.me/hc/en-us/articles/19559573010583-How-to-Delete-Your-Fitbod-Account
- [J1] https://support.jefit.com/hc/en-us/articles/203707060
- [J2] https://support.jefit.com/hc/en-us/articles/200228159
- [J3] https://www.jefit.com/wp/jefit-news-product-updates/elementor-25282/
- [J4] https://www.jefit.com/blog (spreadsheet vs workout tracker; marketing)
- [M1] https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal
- [M2] https://help.macrofactorapp.com/en/articles/68-export-your-data
- [M3] https://help.macrofactorapp.com/en/articles/99-edit-or-delete-past-weight-entries
- [M4] https://help.macrofactorapp.com/en/articles/31-how-do-i-reset-my-data
- [P1] https://support.myfitnesspal.com/hc/en-us/articles/360032274432-Customize-your-nutritional-goals
- [P2] https://support.myfitnesspal.com/hc/en-us/articles/360032273352
- [P3] https://support.myfitnesspal.com/hc/en-us/articles/360032624431
- [P4] https://support.myfitnesspal.com/hc/en-us/articles/360032622391-How-to-set-up-logging-reminders
- [P5] https://support.myfitnesspal.com/hc/en-us/articles/360032622451
- [A1] https://support.apple.com/guide/iphone/adjust-your-activity-ring-goals-iph9a08e004e/ios
- [A2] https://support.apple.com/en-us/108779
- [A3] https://support.apple.com/guide/iphone/share-your-health-data-iph5ede58c3d/ios
- [V1] https://support.strava.com/hc/en-us/articles/216918687-Goals-on-Strava
- [V2] https://support.strava.com/hc/en-us/articles/360057378851
- [V3] https://support.strava.com/en-us/articles/15401919-how-do-i-export-my-strava-data
- [V4] https://support.strava.com/en-us/articles/15401906-how-do-i-delete-my-strava-account

## My recommendations

The user asked me to decide. Ranked by value to users. Everything here fits
V1: offline, local, no account, nothing derived from sessions on Profile.

**Build (in scope)**

1. **Bodyweight that cannot go wrong** (B1, B2, B3). Refuse anything outside
   20 to 250 kg, with an inline reason ("Between 20 and 250 kg"); Record is
   disabled until the value is valid. At 250 kg the 1.6 g/kg suggestion is
   exactly the 400 g target cap, so a valid weight always gives a valid
   suggestion. Dates use `date_labels.dart`. After Record, a polite status
   line ("Recorded 74.5 kg for today") is read by VoiceOver. The copy says
   that today's entry can be replaced until midnight, and that after today it
   stays. *Why first:* this is the only bad data on the tab that becomes
   permanent.
2. **Pinned segment control** (B4). The control sits above the scroll view,
   under the pinned header, so you can switch segment from anywhere on a long
   Diet day. It follows the same reasoning as the pinned app bar rule.
3. **Reminders that tell the truth** (B6, B7, B8, B11, B5). Schedule shows
   "Pick at least one training day to get a reminder" when Remind me is on
   with no days. The Diet Reminders row says "Off in Settings" when
   permission was revoked and "None chosen" when no reminder is selected, and
   slot headers drop their time then. Time rows are named ("Breakfast time").
   The disabled reason appears once, not five times. The off note gets an
   **Open Settings** link through a small native method. Saves update state
   before the write, so quick taps never lose a day. One notification
   permission provider, refreshed on resume, replaces the two copies in the
   screens.
4. **Current values on the Personal rows** (B12): "74.5 kg · female diagram",
   "No weight yet · male diagram". These are authored values, so they are
   allowed on Profile (ADR 0004).
5. **Bodyweight trend** on Personal details: a small chart of the weigh-ins
   (two or more), drawn with a `CustomPainter` in the closed palette like the
   History progress chart, plus one spoken sentence ("From 72 to 74.5 kg over
   3 weigh-ins since 27 Oct"). The data is authored, not derived from
   sessions, so this does not break the placement rule.
6. **The suggestion follows a weigh-in, visibly** (B13). After Record, if a
   target is set and the new suggestion differs from it, the status line adds
   "Protein suggestion is now 120 g" with an **Update target** action that
   opens the target screen with that value filled in. The target screen names
   the weigh-in it uses ("from your 74.5 kg weigh-in on 10 Nov"). The stored
   target never changes by itself (ADR 0007: accepting stores a number).
7. **Export that is complete and spreadsheet-ready** (B9, B10). Export is
   enabled for any entered data. The counts list the schedule. The JSON gains
   `reminders`. The share sheet carries a second file, a **CSV of every
   completed set** (date, workout, exercise, load type, set, weight_kg, reps,
   added_kg, assist_kg, duration_sec), with units in the column names.
8. **Delete all data offers Export first** inside the screen, and says that
   files already exported or shared are not touched.
9. **About** at the bottom of Personal: the version, "Your data stays on this
   phone. TurtleLift has no account and sends nothing anywhere.", and
   **Open-source licences** (`showLicensePage`). The version is a constant
   that a test checks against `pubspec.yaml`, so no plugin is added.

**Not building, with reasons**

- **lb units.** `docs/04` and `00` §11 decided kg-only for V1. The food list
  and the PRD target Indian users (IFCT 2017, `docs/adr/0007`), where gyms
  and scales use kg. Pounds would touch every weight input, stepper increment,
  set format, chart axis, PB comparison and the export. That is a cross-app
  change needing its own ADR and plate-rounding rules (Fitbod warns of
  rounding drift [F1]). **Left for the user** as the first V1.x candidate.
- **Editing or deleting past weigh-ins.** MacroFactor and Apple allow it
  [M3][A2], but here it would silently re-price calories on workouts the user
  already saw and shared (KD5, `docs/04`). Validation (item 1) plus same-day
  replacement covers the mistake case.
- **Import from a file.** It is high value on paper: an offline app's only
  way to move phones. But it needs a file-picker plugin (Swift Package Manager
  support must be verified), merge rules against an immutable weight series
  and dated plans, and conflict handling. iOS device backups already carry the
  database. **Left for the user** as a later ADR.
- **Automatic protein targets that move with weight** (MacroFactor's coach).
  They would rewrite a number the user chose. ADR 0007 says accepting stores
  the number. Item 6 gives the visible-moment half of the idea instead.
- **Body measurements, body fat, progress photos.** `docs/04` limits the
  personal data the app collects to bodyweight and gender.
- **Apple Health / Google Fit sync.** Wearables and integrations are out of
  scope (CLAUDE.md).
- **A typed "DELETE" confirmation.** With no account there is no password to
  ask for. A separate screen plus a destructive-colour dialog is already two
  deliberate steps, and Export now sits on the screen as the softer exit.
- **Weekly goal as a count** (Strong, Strava). ADR 0005 chose weekdays. A
  count adds a second consistency measure beside the streak.
- **Account deletion, cloud backup, premium, ads, social.** Out of scope.

## Build plan (slices, test-first)

1. Bodyweight entry: range, reason, dates, status, today copy (B1-B3).
2. Bodyweight trend chart, and the suggestion follow-up after a weigh-in (B13).
3. Profile root: pinned segment, current values on rows, About (B4, B12).
4. Reminders: lost update, no-days hint, honest Diet row, labels, Open
   Settings, shared permission provider (B5-B8, B11).
5. Data: export enablement and counts, reminders in JSON, CSV, Export on the
   delete screen (B9, B10).
6. Docs: ADR 0014, `00`, `04`, CLAUDE.md, turtle-qa table.
7. Maestro: new flows 28 onward; update 04, 05, 06, 08, 09 where behaviour
   deliberately changes.
8. Verify: analyze, tests, `qa.sh --fast`, every Maestro flow on the 17e, Pro
   Max and large-text spot checks, install on the review iPhone 17,
   screenshots.
