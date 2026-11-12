# History tab: audit and production plan

Date: 2026-11-10. Branch audited: `taste-pass-production-polish` at `444b350`, detached in a worktree. Nothing in the app was changed.

> **Progress note.**
> **Done:**
> - Read the docs (`00`, `01`, `04`, ADRs 0004/0008/0011/0012), the prototypes (screens 4, 13 and 22), turtle-taste, and every History file.
> - Device pass on the iPhone 17e:
>   - seeded debug build: calendar, day panel, Recent, All workouts, detail, Edit, set logging, exercise history, rename, delete, then the Muscles map after the delete;
>   - empty `TURTLE_NO_SEED` build: empty state, plus logging a workout and removing its only exercise;
>   - largest text size (reset afterwards);
>   - accessibility tree via Maestro `hierarchy`.
> - Spot check on the iPhone 17 Pro Max (detail screen).
> - Timing run of the personal-best projection at 100, 300 and 1,000 sessions.
> - Competitor research (8 apps, primary sources).
>
> **Not driven on a device:**
> - A session dated last year. The missing year is certain from code: the date picker allows five years back (`session_date_control.dart:84`), and three date formatters print no year.
> - Reduce Motion. Checked in code: calendar chevrons jump when it is on (`history_calendar_card.dart:100`); nothing else in History animates.
> - VoiceOver itself. I read the accessibility tree instead.
> - A 300-session history on the device. The existing fixture, `test/qa_history_volume_test.dart`, only counts queries. I timed the CPU side with a throwaway test in the scratchpad.
>
> Screenshots: `/private/tmp/claude-501/-Users-heera-Desktop-Dev-turtle-lift/715c8386-c38a-4220-9a7a-ef3a449b043a/scratchpad/history-audit/` (`h01`–`h24` and `p01`; `s_` files are downscaled). That folder is session scratch, so copy any shots you want to keep.

---

## Verdict

**Not production ready.**

**What works:**
- The core loop. Calendar, Recent and All workouts read one derived list.
- Deleting a workout recomputes the calendar, PBs, streak and the Muscles map with nothing stored. I checked this on the device (h15 to h18).
- PB rules follow the spec: assisted is inverted, the first time never counts, and the mark needs a strictly greater set.

**What blocks it:**
1. **Silent data loss on rename.** A new workout name is saved only when Return is pressed. Tap anywhere else, or go back, and the name is gone (B1).
2. **A past workout cannot be re-dated.** `00` §11 and `04` both promise it ("what makes the streak promise … true for past mistakes"), and prototype 22 has *Change date*. The date control exists only on the live workout (B2).
3. **Two "same" hero cards disagree.** The History detail and the editor show different muscles for the same workout. The detail fills whole parent groups, so it paints the rear delt for a Push day. They also differ on labels (*Streak* / *Day streak*), on the date (*10 November 2026* / *Today*) and on kcal vs PB (B3).
4. **Dates never show a year.** Rows, exercise history and the share card all omit it, so a workout from 2025 reads exactly like one from this year (B4).
5. **The PB projection is quadratic, which the spec forbids.** It takes 84 ms at 300 sessions and 1.27 s at 1,000 on a desktop, and runs again on every edit of a past workout (B5).
6. **History has no progress view at all.** There are no stats (streak, total workouts and total sets are specced for this tab, `00` §11), and no per-exercise trend. Exercise history cannot be reached from the History tab. Every competitor's history is also its progress surface.

Items 1–5 are S/M fixes. Item 6 is the product work that makes the tab worth opening.

---

## Bugs found

| # | Sev | Bug | Repro | Where | Shot |
|---|---|---|---|---|---|
| B1 | **High** | **Rename is lost unless the keyboard's Return is pressed.** `onTapOutside` only unfocuses. Tapping elsewhere or Back throws the typed name away with no warning. | History → Push day → Edit workout → tap the title → type → tap the map → Back. Still "Push day". | `lib/src/ui/session_summary_screen.dart:374-376` | h11, h12 |
| B2 | **High** | **No way to change a saved workout's date.** The editor has no date control. `SessionDateControl` is used only in `session_overview_body.dart`. Promised by `00` §11, `04` (streak promise) and prototype 22 ("Change date"). | Edit workout on any past session: title, card, What you did, Save as template, Delete. No date. | `session_summary_screen.dart` (absent); `session_date_control.dart` | h08, h09 |
| B3 | **High** | **History detail and the editor are two different cards that disagree.** `04` says it is "the same component".<br>(a) **Muscles:** the detail fills *every sub-group of each trained parent* (`subMuscleGroupIdsFor`). So a Push day paints all three chest bands and the rear delt amber. The editor shows the actual primaries plus steel secondaries.<br>(b) **Labels:** *Streak* vs *Day streak*.<br>(c) **kcal:** the detail shows kcal on a PB day; the editor swaps kcal for PB (ADR 0011 §4).<br>(d) **Date:** "10 November 2026" vs "Today".<br>(e) **Record set:** amber in the detail log, plain in the editor.<br>(f) **Assisted PB:** detail says "PB"; editor and exercise history say "PB · lightest assist".<br>(g) **Calculations:** each card has its own `streakAsOf` and `caloriesFor` (`history_preview_data.dart:525,568` vs `derived.dart:147,411`). | Push day: detail h06 vs editor h08 | `history_session_detail_screen.dart:252-402`; `session_summary_screen.dart:320-440` | h06, h08 |
| B4 | **High** | **No year anywhere a date is printed short.**<br>• `historyDateLabel` gives "7 Nov" (rows, the Workout landing's last-workout line).<br>• `_shortDate` in exercise history gives "first logged 18 Oct" and "18 Oct".<br>• `longDateLabel` gives "Mon 28 Jul" on the editor card, which is **the share card**.<br>• `_relative` counts up to "27 months ago" and never says years.<br>The date picker allows five years back. | Backdate a live session to 2025 (picker) → History row, exercise history and share card all lack the year | `history_session_row.dart:129-145`; `exercise_history_screen.dart:273-290`; `session_date_control.dart:128` | code |
| B5 | **Med–High** (perf) | **The PB projection is O(n²).** `historyProjectionProvider` calls `pbCountFor(session, saved)` for every session. Each call re-sorts all sessions and walks the earlier ones, and copies a set on every exercise (`personal_best.dart:104`). Timed with a throwaway test (6 exercises × 4 sets per session):<br>• 100 sessions: 62 ms<br>• 300 sessions: 84 ms<br>• 1,000 sessions: **1,273 ms** (desktop JIT; a phone is slower).<br>It reruns on every change to saved sessions, including each stepper tap while correcting a past workout. `00` §11 / `01`: "one chronological pass … Not O(n²)". | — | `lib/src/data/history_preview_data.dart:229-250`; `personal_best.dart:91-123` | — |
| B6 | Med | **Removing the last exercise leaves a ghost workout.** The editor allows it, and the result is a row "Workout · Today · 0 exercises · 0 sets" with a calendar dot claiming a trained day. Meanwhile the streak (correctly) ignores it. Delete would be the honest outcome. | Empty build → log bench → History → Edit → long-press the exercise → Remove → Back | `session_summary_screen.dart:269-285`; `active_session.dart:214` | h22–h24 |
| B7 | Med | **Two `resolvedTitle`s.** The History version (`history_preview_data.dart:164`) ignores `templateName`; `derived.dart:179` uses it. With the title cleared, a template workout shows its template name in the editor but "Chest, shoulders, triceps" on its History row and detail. "Quick log" is also inferred as "exactly one exercise with sets" (`:225`), so a template workout with one finished exercise is tagged *quick log*. | Clear a template workout's title (Return) → compare editor vs row | `history_preview_data.dart:164-181, 225` | code |
| B8 | Med | **No swipe-to-delete on History rows**, though `00` §11 and `04` specify it. Delete is three levels deep: detail → Edit workout → scroll → Delete. | — | `history_session_row.dart` | h16 |
| B9 | Med | **Exercise history is a dead end in both directions.**<br>(a) It cannot be reached from History: names in the detail log are not tappable.<br>(b) Its rows open the **editor**, not the read-only detail. So a reader lands in a screen where one tap changes a set, and set logging → See all → editor → set logging nests without end. | Detail → tap "Barbell bench press" (nothing happens); set logging → See all 4 sessions → tap a row | `history_session_detail_screen.dart:439-505`; `exercise_history_screen.dart:165-171` | h06, h13, h14 |
| B10 | Med (a11y) | **Accessibility tree:**<br>• Editor rows have no button role and no hint, so "tap to edit, long-press to remove" is invisible to VoiceOver.<br>• The title field has no label.<br>• Day cells read "10, 1 workout": no weekday, no month, no "today".<br>• Future days read "no workout logged".<br>• The month label is merged with "Days of the week …".<br>• VoiceOver has to step through all 30–31 day cells to reach Recent. | `maestro hierarchy` on the root and the editor | `history_calendar_card.dart:419-443`; `session_summary_screen.dart:633-640, 352` | tree |
| B11 | Low–Med | **Tap targets below the 48pt turtle-taste rule:** the month chevrons are 32pt (`_NavButton`: 20 + 2×6) and day cells 38pt tall. No pressed feedback on rows, day cells or chevrons (all `GestureDetector`). | — | `history_calendar_card.dart:202-239, 63`; `history_session_row.dart:60` | h01 |
| B12 | Low | **A set breaks across lines.** At large text "95kg × ⏎ 7" and "65kg ⏎ × 12" wrap inside a set. It is one `Text.rich` with plain spaces. | Largest text → Leg day detail | `history_session_detail_screen.dart:513-543` | h20 |
| B13 | Low | **Three date formats on one journey:** day panel "Nov 10, 2026" (US order), rows "7 Nov", detail "10 November 2026". Also *sessions* vs *workouts*: "See all 12 sessions" opens "All workouts", and the day panel says "2 sessions". | — | `history_calendar_card.dart:468`; `history_root.dart:94`; `all_sessions_screen.dart:40` | h02, h04, h05 |
| B14 | Low | "See all 1 session" shows when nothing is hidden (fewer sessions than `recentCount`). | Empty build with one workout | `history_root.dart:92` | h24 |
| B15 | Low | Stale month: `_currentMonthStart` is fixed in `initState`, and the tab is kept alive. Open the app on 31 Oct, leave it running past midnight, and the calendar cannot page to November. | — | `history_calendar_card.dart:78-84` | code |
| B16 | Low | `AllSessionsScreen` builds every row eagerly (`ListView(children:)`, not `.builder`). Fine at 50 rows, wasteful at 1,000. | — | `all_sessions_screen.dart:86` | — |
| B17 | Low (docs) | Conflicts, reported per CLAUDE.md rather than resolved here. | — | — | — |

B17 in detail:
- **`00` §11 vs the code on stats.** `00` §11 says streak, total workouts and total sets live **on the History tab**, and prototype 4 shows them. `history_root.dart:29` says "Still no stats block", citing ADR 0003. None of these figures renders anywhere except the streak on a card.
- **`00` §12 vs `CLAUDE.md` on the palette.** `00` §12 is "Chalk & Shell" with amber `#FFA53D`, which the app ships. `CLAUDE.md` still describes ONE DAY titanium (ice `#A9D8FF`).
- **`04` vs the build.** `04` says detail "is the same component as the live workout card". As built, there are two cards (B3) plus a separate editor.
- **`00` §11 vs the build on swipe-to-delete.** Specified in `00` §11, not built (B8).

**Checked and fine:**
- Calendar paging (back 120 months; forward blocked at this month).
- Day panel toggles.
- Multi-session days show two dots.
- Ordering by `performedOn` with a stable tiebreak past 32 rows.
- Delete confirm uses the destructive colour.
- After a delete, both pushed screens pop.
- Muscles map updates after a delete (h15 → h18).
- Calories: the add-weight note shows when no weight was in effect.
- No PB on a first occurrence.
- Assisted inversion in `metricFor`.
- At the largest text size the 1.3× clamp holds and nothing clips except B12.

---

## UX/UI findings by screen

**History root (h01–h04, h19)**
- **It answers "what did I do", never "how am I doing".** There is no stats line, streak, week or month count, or trend (B17, Verdict 6). The calendar shows dots only. There is no density for multi-set days and no streak run.
- **Wasted space.** The calendar is a fixed six rows, so November leaves an empty sixth row. The card is about 340pt tall before Recent, which starts at roughly 55% of the 17e screen.
- **There is no "back to this month" control** once you have paged away, and no month total ("6 workouts").
- **The calendar mostly repeats Recent this month.** The day panel duplicates rows already listed below it, and adds a third date format.
- **Amber is everywhere.** Nearly every row carries "2 PB" or "3 PB", the today ring is amber, and so are the dots. turtle-taste: "One accent on screen at a time". With progressive training most rows earn a PB, so the mark stops carrying news.
- **The row glyph reads as a battery or jar, not a body** (h05). It is a second diagram treatment beside `BodyDiagram`, while `00` §5 calls for one treatment everywhere.

**All workouts (h05)**
- It is a month-grouped list with no search or filter: not by exercise, muscle or template. That is fine at 12 rows and a scroll marathon at 300.
- Month headers carry no counts.
- The title says "All workouts" but the button that opens it says "sessions".

**Session detail (h06, h07, p01)**
- Good bones: card, then log, then Do again, then Edit.
- **Problems:**
  - No **Share** here, though `04` says revisiting a workout is "just as shareable" and prototype 22 puts share in the header. Share lives only on the editor.
  - Exercise names in the log are not links to their history (B9).
  - The title appears twice: the app bar and the card.
  - The map is 200pt here against 280pt in the editor.
  - The secondary muscles (steel) are missing (B3).
  - "Logged · 2 personal bests" repeats the "2 PB" on the card.
- **Edit workout is a ghost text button** leading to a screen that looks identical to the post-workout summary. Nothing says "you are editing a saved workout", and every change saves instantly with no undo.

**Editor = summary screen (h08, h09, h22, h23)**
- **Hidden gestures.** Rows open set logging on tap and remove on long-press, with no chevron, no edit affordance and no visible remove.
- **Missing pieces:**
  - no Change date (B2);
  - no add exercise to a past workout;
  - "Save as template" renders as a muted outlined capsule that looks disabled (h09).
- **The delete confirm is good** ("permanently removes …"). But it does not say that records and streak may change, and there is no undo. That fits "no soft delete" in V1, but Hevy and Strava both lean on export or restore here.

**Exercise history (h14)**
- **Information, but no shape.**
  - The summary line ("4 sessions · best 77.5kg × 8 · first logged 18 Oct") has no year.
  - There is no trend, chart or records-by-rep-count.
  - Every session is a bordered card, against divider rows elsewhere in History.
  - The record set is not highlighted in amber here, but it is in the detail log.
- **Reachability.** It is reachable only from set logging and from Muscles detail (ADR 0012), never from History.

**Empty state (h21)**
- "No workouts yet. Finish your first session and it'll show up here." There is no action. A secondary "Start a workout" (it would switch to the Workout tab) removes a dead end.
- There is no way to log a past workout from History, though the calendar is the natural place to backfill (Hevy, StrengthLog [H1][S4]).

**Accessibility:** B10, B11, B12. Rows on the root are well labelled: "Push day, 2 personal bests, Today · 3 exercises · 9 sets".

---

## Competitors (8)

Primary sources only. Several help centres return 403 to a direct fetch; for those the claim comes from the search engine's index of the same primary URL. "nv" means not verified. I kept the default set: Apple Fitness and Strava are not strength loggers, but they set the platform's baseline for calendars, streaks and deletion.

| App | Organisation | Session detail | Progress views | Records | Search / filter | Editing | Standout |
|---|---|---|---|---|---|---|---|
| **Hevy** | Newest-first list; month calendar that zooms to year and multi-year; rest days since last workout; configurable week start [H1][H2] | Sets, weight, reps, RPE, notes, duration; medal on PR sets [H2] | Per-exercise graph; sets per muscle weekly/monthly; muscle distribution chart + body map; 30d/3m/1y/all [H2] | Heaviest, best 1RM, best set volume, best session volume. A quiet **Set Records** table (heaviest per rep count) with no alert. Assisted = reps only [H3] | Library search; workout search nv | Edit via ⋯; delete is confirmed and "cannot be recovered"; export advised; log past workouts from the calendar [H1][H4] | Two record tiers: headline + quiet per-rep table [H3] |
| **Strong** | History list [S2] | nv beyond edit [S3] | Exercise detail: About / History / Charts / Records; workouts-per-week widget [S2][S5] | Best at each rep count next to a predicted best; records only ≤12 reps [S1] | nv | History → ⋯ → Edit; history cannot be reset; "Start History From" hides old data without deleting [S3][S4] | Actual vs predicted records, capped at 12 reps [S1] |
| **Fitbod** | Log list; report calendar up to 365 days [F4] | Sets, reps, weight, notes [F1][F5] | Exercise charts (up to 7 metrics); body recovery map, tap a muscle for its history [F2][F3] | Estimated strength (e1RM; max reps for bodyweight), heaviest, max reps; the estimate decays without training [F2] | nv | ⋯ to edit or delete; open a workout to edit sets [F1] | The estimate reflects current strength, not an all-time high [F2] |
| **JEFIT** | Progress tab: calendar heatmap, streak [J1] | Duration, sets, records, e1RM per set, body map [J1] | 1RM chart; sets per muscle; longer ranges are paid [J1] | PR pop-up and summary; definitions nv [J1] | nv | From the calendar; steps nv [J1] | Charts open at your data; empty weeks say "No Data" [J2] |
| **StrengthLog** | Training log list; calendar can **backfill** missed days [L4] | nv | Per-exercise quick stats; heat maps over any period (paid) [L3][L4] | Records at every rep count (1/3/5/10RM); **Yearly Records** next to all-time PRs; tap a record for its graph [L1] | **Search by exercise, comment or workout name** [L2] | Removing a wrong PR = edit its workout; the list recomputes [L5] | Yearly records give returning lifters reachable targets [L1] |
| **Alpha Progression** | History list; weekly/monthly/yearly reports [A1] | Summary lists every record beaten, including per muscle group [A2] | Exercise performance, strength, sets per muscle, workouts per week; reports compare against the previous period [A1][A3] | Heaviest, most reps, e1RM/10RM, best per muscle group [A2] | Exercise list sorted by recently performed [A1] | Edit or delete; changes flow through the app; never alters the plan [A1] | Period-over-period reports [A1] |
| **Apple Fitness** | Summary → Sessions; "Show More → All Workouts" filter by type [P3] | Details, splits, heart rate, effort [P1] | Trends: last 90 days against the last 365, with arrows; needs 180 days of data [P2] | n/a | Filter by type [P3] | Swipe to delete, offered as "Delete Workout" or "… & Data"; log past workouts (iOS 26.1+) [P1] | Trends wait until there is enough data to be honest [P2] |
| **Strava** | Training Log: weekly rows of circles; jump to any month or year; filter by sport/tag [V1] | Key stats; muscle map for strength sessions [V6] | Training Log, Best Efforts, Streaks [V2][V5] | Best efforts: top 3 lifetime + top 10 per year [V5] | Sport and tag filters [V1] | Edit; confirmed delete; **30-day restore**, and restoring brings the streak back [V3][V4] | Restore window [V3] |

**Principles to take** (behaviour only, never a look, name or artwork):
1. **Records are recomputed from history**, and an edit or delete moves them [H5][L5][A1]. TurtleLift already does this; it should also say so in the delete dialog.
2. **The year is always recoverable.** Calendars zoom out to a year [H1][V1], and StrengthLog/Strava split records by year [L1][V5]. A logbook without years cannot be read back.
3. **Each exercise's history is one tap from wherever the exercise appears** [S2][F2][A1].
4. **A per-exercise trend of the best set, by load type** (reps for bodyweight, time for timed) [F2][H3]. TurtleLift adds the inversion for assisted, which no competitor has (Hevy just drops weight PRs) [H3], so it needs its own tests.
5. **A quiet records tier**: best at each rep count, or this year's best, beside the headline PB [H3][S1][L1][V5]. It gives a lifter who has plateaued something to beat without inventing badges.
6. **Consistency as countable facts over a labelled period**: workouts and sets per week or month, compared with the previous period [A1][S5][P2]. Many apps count streaks by week [H1][V2][A1]; TurtleLift's 3-day-gap rule is decided, so show it clearly rather than change it.
7. **Search history by exercise and by text** [L2][V1][P3].
8. **Backfill from the calendar**: tap a past day to log it [H1][L4][P1].
9. **Safe deletion**: confirm, warn that it is permanent, point to export, or allow restore [H4][V3][P1].
10. **No empty or misleading charts**: open at the data, and say so when there is too little [J2][P2].
11. **Editing a past session never changes the plan or template** [A1]. TurtleLift already does this.

**Sources**
- [H1] https://www.hevyapp.com/features/gym-consistency/
- [H2] https://www.hevyapp.com/features/gym-progress/
- [H3] https://help.hevyapp.com/hc/en-us/articles/38279531346455-Set-Records-vs-Personal-Records
- [H4] https://help.hevyapp.com/hc/en-us/articles/38030200802583-How-to-Delete-Comments-Sets-Workouts-Routines-Your-Hevy-Account
- [H5] https://help.hevyapp.com/hc/en-us/articles/34896293707927-Set-Types-in-Hevy-Explained-Drop-Sets-Warm-Up-Sets-and-More
- [S1] https://help.strongapp.io/article/216-exercise-records-screen
- [S2] https://help.strongapp.io/article/237-about-exercise-detail
- [S3] https://help.strongapp.io/article/249-how-do-i-edit-a-past-workout
- [S4] https://help.strongapp.io/article/250-can-i-reset-my-workout-history
- [S5] https://help.strongapp.io/article/239-profile-widgets
- [F1] https://help.fitbod.me/hc/en-us/articles/360006335593-Editing-Workouts-in-Fitbod
- [F2] https://help.fitbod.me/hc/en-us/articles/12732749777047-Fitbod-Metrics-Records
- [F3] https://help.fitbod.me/hc/en-us/articles/360006269014-Muscle-Recovery
- [F4] https://help.fitbod.me/hc/en-us/sections/1500000505721-Workout-Schedule-Logging
- [F5] https://help.fitbod.me/hc/en-us/articles/21486783720087-Exercise-Notes
- [J1] https://www.jefit.com/blog/jefit-training-analysis-guide
- [J2] https://apps.apple.com/us/app/jefit-workout-plan-gym-tracker/id449810000
- [L1] https://help.strengthlog.com/help-article/personal-records-and-yearly-records/
- [L2] https://help.strengthlog.com/help-article/searching-in-the-training-log/
- [L3] https://www.strengthlog.com/how-to-effectively-use-a-workout-log-app/
- [L4] https://apps.apple.com/app/id1434229662
- [L5] https://help.strengthlog.com/help-article/remove-old-personal-records/
- [A1] https://alphaprogression.com/en/blog/alpha-progression-guide
- [A2] https://apps.apple.com/us/app/gym-workout-alpha-progression/id1462277793
- [A3] https://alphaprogression.com/en
- [P1] https://support.apple.com/guide/iphone/log-a-workout-iphf16df7c54/ios
- [P2] https://support.apple.com/guide/iphone/see-your-activity-history-trends-and-awards-iph4c34a8a95/ios
- [P3] https://support.apple.com/bn-in/guide/watch/apd91635a9e6/7.0
- [V1] https://support.strava.com/hc/en-us/articles/206535704-Training-Log
- [V2] https://support.strava.com/en-us/articles/15401580-streaks-on-strava
- [V3] https://support.strava.com/en-us/articles/15401935-how-do-i-delete-an-activity
- [V4] https://support.strava.com/en-us/collections/19669229-managing-and-editing-activities
- [V5] https://support.strava.com/en-us/articles/15401661-how-do-i-best-efforts-work-for-running-on-strava
- [V6] https://stories.strava.com/articles/whats-new-on-strava-muscle-maps-new-sports-and-expanded-training-tools

---

## Prioritised improvements

Effort: S is under half a day, M is 1–2 days, L is 3 days or more. "Decision" means the item needs a yes from you first.

**Hard constraints respected throughout:**
- **No kg volume metric** (`00` §3, `01` §Derived values). Set count is the volume proxy.
- **Nothing derived is stored.**
- **No badges, AI, cloud or social.**

| # | What | Why + source | Screen / file | Effort | Decision |
|---|---|---|---|---|---|
| 1 | **Save the title on blur and on pop**, not only on Return: `onTapOutside`/`onEditingComplete`, plus a `FocusNode` listener that saves when focus is lost. | B1, data loss | `session_summary_screen.dart:352-377` | S | No |
| 2 | **Change date on a saved workout.** Reuse `SessionDateControl`'s picker against `setPerformedOn(sessionId, date)`, which already exists in the store. Place it under the card date. Streak, PBs and ordering re-derive. | B2. `00` §11, `04`, prototype 22 | `session_summary_screen.dart`; `session_date_control.dart`; `active_session.dart:221` | S–M | No |
| 3 | **One hero card.** Extract the editor's card as a single `SessionCard(session, editable:)` used by both the detail and the editor. It uses `workedSubGroups` (primary + secondary), `derived.dart` streak/kcal, one date label, "Day streak", and the PB-replaces-kcal rule. Delete `history_preview_data`'s second `streakAsOf`/`caloriesFor`/`resolvedTitle`. Use one PB set highlight and "PB · lightest assist" everywhere. | B3, B7. `04` "same component" | `history_session_detail_screen.dart`, `session_summary_screen.dart`, `history_preview_data.dart` | M | No |
| 4 | **Year in dates.** One `formatHistoryDate(date, {now})` that omits the year in the current year and adds it otherwise ("7 Nov" → "7 Nov 2025"). Always print the year on the share card and in "first logged". `_relative` says "1 year ago" from 12 months on. Exercise history and All workouts get year headers once a list spans years. One date order everywhere (day month), so the day panel's "Nov 10, 2026" goes. | B4, B13. Principle 2 [H1][L1][V5] | `history_session_row.dart`, `exercise_history_screen.dart`, `session_date_control.dart`, `history_calendar_card.dart` | S | Light: show the year when not this year, or always? |
| 5 | **Single-pass PB projection.** One chronological walk yields `pbCount` per session, plus `recordSetIndex` per session exercise, cached in a provider. `pbCountFor`, `isPersonalBest` and the detail log all read it. Keep the same baseline (running best advances at a date boundary) and the assisted inversion. | B5. `00` §11 | `personal_best.dart`, `history_preview_data.dart` | M | No |
| 6 | **Exercise history reachable from History.** Exercise names in the detail log become rows with a chevron, opening `ExerciseHistoryScreen`. Exercise-history rows open the **read-only detail**, not the editor. | B9. Principle 3 [S2][F2][A1] | `history_session_detail_screen.dart`, `exercise_history_screen.dart:165` | S | No |
| 7 | **Per-exercise progress chart** at the top of exercise history. Plot the best set per session over time, using the same `metricFor` the PB uses: weight for weighted, reps for bodyweight, seconds for timed, assistance for assisted with the axis inverted and labelled "less assist is better". Range chips: 3 months / 1 year / all. PB points in amber. Under 3 sessions, show text, not a chart. Custom painter, no package. | Principles 4, 10 [F2][H2][J2]. Builds on `metricFor` | `exercise_history_screen.dart`, new `progress_chart.dart` | M–L | **Yes**: new surface. And should an **e1RM** line (modelled) appear? I recommend no for V1: best set only. |
| 8 | **Records by rep count** on exercise history: a small "Best at" table (best weight at 1–12 reps for weighted; best reps for bodyweight; longest hold for timed; lightest assist at each rep count for assisted). Derived and quiet: no alerts, no badges. | Principle 5 [S1][H3][L1] | `exercise_history_screen.dart`, `personal_best.dart` | M | **Yes**: changes what "PB" means to the user? (It does not change the PB rule; it adds a reference table.) |
| 9 | **History stats line** at the root, as `00` §11 specifies: current streak with its explainer (`04` copy), total workouts, total sets. Plus "This month: N workouts · M sets" under the calendar header for the month shown. It must not duplicate the Workout landing's current-week figure (ADR 0008), so show the month, not the week. | B17, Verdict 6. Principle 6 [A1][S5] | `history_root.dart`, `history_calendar_card.dart` | S–M | **Yes**: confirm that `00` §11 wins over the "no stats block" comment, and the month-not-week rule |
| 10 | **Fix the ghost workout.** If removing an exercise would leave zero completed sets, the confirm becomes "This is the only exercise. Delete the workout?" and deletes the session. Also filter zero-set sessions out of History, defensively. | B6 | `session_summary_screen.dart:269`, `history_preview_data.dart:184` | S | No |
| 11 | **Search and filter All workouts** by exercise name, title or note (`searchFold`), and by muscle group (chips from the taxonomy). The filter state lives in memory. Use `ListView.builder` with sticky month headers carrying counts ("October 2026 · 9 workouts"). | Principle 7 [L2][V1][P3]; B16 | `all_sessions_screen.dart` | M | No |
| 12 | **Swipe-to-delete on History rows**, with the same confirm. Add VoiceOver custom actions (Delete, Open) on rows. | B8. `00` §11, `04` | `history_session_row.dart` | S | No |
| 13 | **Editor clarity and safety.**<br>• Title "Edit workout" when opened from History; summary title only after Finish.<br>• Visible chevrons on rows and a visible remove (trailing ⋯ or an Edit list) instead of long-press only.<br>• Button role and hints for VoiceOver.<br>• Label the title field.<br>• Make "Save as template" look enabled.<br>• The delete dialog names the date and says "Records and your streak will update".<br>• "Add exercise" to a past workout. | B10; principle 9 [H4] | `session_summary_screen.dart` | M | Light: add exercise to a past workout (`00` §11 lists remove only) |
| 14 | **Share from History detail** (header share icon, as in prototype 22), rendering the unified card from #3. | `04` "just as shareable"; ADR 0011 §4 | `history_session_detail_screen.dart` | S (after #3) | No |
| 15 | **Calendar polish.**<br>• Size to the month's real row count. Weeks change height, so animate the size (`AnimatedSize`, off under Reduce Motion).<br>• 44–48pt chevrons, plus a "This month" jump when paged away.<br>• Mute future days and label them "not yet" for VoiceOver.<br>• Day labels "Tuesday 10 November, today, 2 workouts".<br>• Merge the weekday header out of the month heading.<br>• Pressed feedback.<br>• Recompute the current month on resume (B15). | B10, B11, B15 | `history_calendar_card.dart` | M | No |
| 16 | **Calendar shows streak runs.** A thin connector under consecutive days whose gap is ≤3 (exactly the streak rule), so "how does my streak work" is visible. Day density: one dot per session, max 3. | Principle 6, `04` streak transparency | `history_calendar_card.dart` | M | **Yes**: a new visual element in the calendar |
| 17 | **Tone down amber on rows.** Keep "PB" on the detail card and log. On list rows show it only when the session holds a record that still stands, or use a muted count. | turtle-taste "one accent at a time" | `history_session_row.dart` | S | **Yes**: changes what a row says (`00` §11 says the pill renders when ≥1) |
| 18 | **Empty-state action and backfill.** The empty state gets "Start a workout" (switches tab). Tapping an empty past day offers "Log a workout for Tue 3 Nov", which starts a session with `performedOn` set. | Principle 8 [H1][L4][P1] | `history_root.dart`, `history_calendar_card.dart`, `session_entry.dart` | M | **Yes**: backfill from History is a new entry point |
| 19 | **Small fixes:**<br>• Non-breaking spaces inside set tokens (B12).<br>• Hide "See all" when everything is shown (B14).<br>• "workouts" everywhere instead of "sessions".<br>• Drop the duplicate card title on detail. | B12–B14 | various | S | No |
| 20 | **Docs reconcile:**<br>• `CLAUDE.md` palette paragraph vs `00` §12.<br>• `00` §11 stats vs the code comment.<br>• `04` "same component".<br>• The glyph vs "one diagram treatment" (`00` §5). | B17 | docs | S | Yes: which wins |

**Later, or in conflict with CLAUDE.md scope. Do not build in V1.**
- **A volume (kg) chart or "total lifted".** Banned by `00` §3 / `01` because it silently excludes bodyweight and timed work. Sets per muscle per week is the honest substitute; it fits under #9 or the Muscles tab if wanted.
- **An e1RM or "estimated strength" with decay** (Fitbod [F2]). A modelled number, not a fact. Revisit after #7 ships.
- **Restore-within-30-days / soft delete** (Strava [V3]). Out of scope ("no soft delete"). Export is the stated safety net, and the delete dialog could point to it.
- **Year-in-review, monthly reports with verdicts, "best month" call-outs.** These drift towards achievements. Plain period counts (#9) are the in-scope version.
- **Weekly streak model** (Hevy/Strava/Alpha [H1][V2][A1]). The 3-day rule is decided in `01`; changing it is a product call, not polish.
- **Sharing history or charts.** That is social; the session card is the one shareable surface.
- **"Start History From" hiding** (Strong [S4]). Low value offline; Delete all data covers the reset.

---

## Build order (slices)

Each slice: tests first, then a Maestro flow under `.maestro/flows/` (next numbers 21+), run by `tool/maestro_run.sh` on the 17e and the Pro Max, then taste shots.

1. **Data safety (#1, #2, #10).**
   - Widget tests in `session_summary_test.dart`:
     - typing a title then tapping outside saves it;
     - typing then popping saves it;
     - an empty title restores the fallback;
     - the Change date control appears on a saved workout, cannot pick a future day, and re-orders History;
     - the streak on a later card changes after backdating;
     - removing the only exercise offers delete and leaves no zero-set row.
   - Unit test: History omits zero-set sessions.
   - Maestro `21_history_edit_safety.yaml`: rename and tap away → Back → row shows the new name. Change date to 3 days ago → calendar dot moves. Remove the last exercise → the workout is gone.
2. **One card, one derivation (#3, #5, #14, #6).**
   - Unit tests:
     - a single-pass projection equals the old `pbCountFor` on randomised histories, including same-day pairs, backdating and assisted;
     - a 1,000-session projection runs under 50 ms in `flutter test`, as a perf guard beside `qa_history_volume_test.dart`;
     - `resolvedTitle` is a single function, and templateName is used.
   - Widget tests:
     - detail and editor render the same `SessionCard` (golden or key equality);
     - Push day fills mid chest, not the rear delt;
     - assisted shows "PB · lightest assist" in all three places;
     - tapping a log exercise opens its history;
     - exercise history rows open the detail, not the editor.
   - Maestro `22_history_card_parity.yaml`: assert the same figures on detail and editor; Share opens the sheet (stubbed).
3. **Dates (#4, #19).**
   - Unit tests in `history_date_test.dart`: same year → "7 Nov"; previous year → "7 Nov 2025"; share card always has the year; `_relative` at 12, 13 and 25 months; DST boundaries.
   - Widget test: All workouts spanning years shows year headers.
   - Maestro: backdate a live session to last December via the picker, Finish, and assert "Dec 2025" on the row.
4. **Exercise progress (#7, #8), after the decision.**
   - Unit tests on a derived series per load type: weighted max weight; bodyweight reps; timed seconds; assisted inverted, with lower assistance plotting higher. Editing or deleting a session changes the series. Records-by-rep-count table per type.
   - Widget tests: fewer than 3 sessions shows text and no chart; range chips are in-memory only; colours come from §12 (`theme_palette_test`).
   - Maestro `23_exercise_progress.yaml`: log three bench sessions with rising weight, then open exercise history from the History detail; assert the chart semantics label ("Best set rose from 60 to 70 kg over 3 sessions") and the "Best at 8 reps" row.
5. **Root stats and calendar (#9, #15, #16), after the decision.**
   - Widget tests:
     - stats line equals the derived values;
     - month total follows paging;
     - no current-week figure on History (ADR 0008 guard, extend `week_strip_test.dart`);
     - calendar height equals the month's row count;
     - chevrons ≥48pt;
     - day labels include weekday, month and "today";
     - future days not tappable;
     - stale month refreshes on resume (fake clock).
   - Maestro `24_history_calendar.yaml`: page back 3 months, then "This month"; open a day; assert labels via `hierarchy`.
6. **Find and act (#11, #12, #13, #18).**
   - Widget tests: search by exercise, note and title; muscle chip filter; the list is lazily built; swipe-to-delete confirms; VoiceOver custom actions exist; editor rows expose a button role and hint; empty state shows Start a workout; tapping an empty past day offers backfill with that `performedOn`.
   - Maestro `25_history_find_delete.yaml`: search "bench" → 4 rows; swipe-delete one → count drops and the Muscles map follows.
7. **Amber and docs (#17, #20)** once decided. Taste shots on both devices.

---

## Open questions for you

1. **Stats on the History tab** (#9): `00` §11 and prototype 4 put streak, total workouts and total sets here; the code comment says "no stats block". *Recommended:* follow `00` §11. Add one stats line at the top, plus a month total for the month shown. Never the current week (ADR 0008).
2. **Per-exercise progress chart** (#7): build it, and with which metric? *Recommended:* yes, best set per session by load type, inverted for assisted. No e1RM line in V1.
3. **Records by rep count** (#8): add the quiet "Best at" table? *Recommended:* yes, on exercise history only, with no alerts. It is the plateau answer competitors converge on and needs no badges.
4. **Year format** (#4): always show the year, or only when it is not this year? *Recommended:* only when not this year in lists. Always on the share card and in "first logged".
5. **Streak runs on the calendar** (#16)? *Recommended:* yes. A thin connector drawn by the exact ≤3-day rule makes the streak explainable at a glance.
6. **PB on list rows** (#17): keep "N PB" on every row that earned one, or quieten it? *Recommended:* keep the mark on detail. On rows, use a muted "PB" with no count so amber stops repeating down the list.
7. **Backfill from the calendar and add exercise to a past workout** (#18, #13)? *Recommended:* yes to both. Both reuse existing flows, and backfill is the natural use of a calendar.
8. **Docs conflicts** (B17): update `CLAUDE.md`'s palette paragraph to match `00` §12 (the shipped amber), and amend `04`'s "same component" once #3 lands. *Recommended:* yes.
