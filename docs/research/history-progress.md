# History tab build: progress

Worktree detached at `origin/taste-pass-production-polish` (444b350). Plan:
`docs/research/history-tab-audit.md` (seven slices). User decisions 1-8 approved
(stats line + month total, progress chart, Best at table, year only when not this
year in lists, streak runs on the calendar, muted "PB" on rows, backfill and add
exercise to a past workout, docs + ADR 0013).

Baseline: `flutter test` 1445 green.

## Slices

| # | Slice | Status |
|---|---|---|
| 1 | Data safety (B1 rename on blur/pop, B2 change date, B6 ghost workout) | done, 1455 green; Maestro 21 written (all flows run on device at the end) |
| 2 | One card, one derivation (B3, B5, B7, B9, share on detail) | done, 1464 green; Maestro 22 written |
| 3 | Dates (B4, B13, B14) | done, 1481 green; Maestro 23 written |
| 4 | Exercise progress chart + Best at | done, 1498 green; Maestro 24 written |
| 5 | Root stats + calendar (B10, B11, B15, streak runs) | done, 1511 green; Maestro 25 written |
| 6 | Find and act (search/filter, swipe delete, editor clarity, backfill, empty action) | done, 1523 green; Maestro 26, 27 written |
| 7 | Amber + docs (ADR 0013, CLAUDE.md, 04, 00) | done (amber: quiet row PB, neutral today ring and open day, grey streak run). ADR 0013 written; `00` §11, `04`, CLAUDE.md (palette paragraph was already Chalk & Shell on this branch; added the History bullet), turtle-qa flow table |
| 8 | Verify | done: `tool/qa.sh --fast` all PASS (analyze, 1523 tests, TZ run, generated, sync, drift). Maestro on 17e: all 27 flows + 07 scripted pass (01 and 26 needed flow fixes, rerun green; one run hit a simulator "device unreachable" flake), no app exceptions. Pro Max spot check and 17e largest text: found and fixed two visual bugs (streak connector laid out at 0px: widget test now checks drawn height; "Day streak" wrapped at 1.3x: label now one line, scales down). Review iPhone 17 has the final build installed over its data, running. Screenshots in the session scratchpad `history-build/`. |

## Log

- Slice 1: `test/history_edit_safety_test.dart` (10). Title commits on Return, focus loss and dispose (notifier held from initState: Riverpod 3 refuses `ref` after dispose). `workoutDatePickerProvider` / `showWorkoutDatePicker` in `session_date_control.dart`, shared by the live chip and the editor's Change date. Removing the only exercise with work offers "Delete this workout?". `historySessionsProvider` drops zero-set sessions. New `lib/src/data/date_labels.dart` (wired fully in slice 3). Maestro 21 + `subflows/pick_days_ago.yaml`.
- Slice 2: `test/history_card_parity_test.dart` (11). `personalBestProjection` (one pass, date-grouped baseline) + `sessionRecordsProvider`; `SessionRecords.recordSetIds`. `titleFromParts` in `derived.dart` is the one title chain; `HistorySession.templateName`; quick log = one exercise and no template. New `lib/src/ui/session_card.dart`: `SessionCard` (used by detail and editor), `SessionSetLine` (record set amber, NBSP inside sets), `shareSessionCard`, sharer provider, `viewsForMuscles` (re-exported from the summary screen). Detail: header Share, "What you did" log rows open exercise history. Editor: "Edit workout" header when opened from History, visible remove control, title field labelled. Exercise history rows open the read-only detail (`sessionKey`). Removed History's second `streakAsOf`/`caloriesFor` and `subMuscleGroupIdsFor` (and its 3 tests, the code is gone). Flow 01's "Streak" became "Day streak".
- Slice 3: `test/history_date_test.dart` (17). `date_labels.dart` is the one formatter (short / weekday / card / with-year / spoken / relative / ago). `historyDateLabel` and `longDateLabel` delegate to it; day panel "Tue 10 Nov · 2 workouts"; "See all N workouts" only when more than Recent shows. Maestro 23 (backdate to last December).
- Slice 4: `test/exercise_progress_test.dart` (17). `lib/src/data/exercise_progress.dart` (`exerciseProgressSeries`, `bestAtTable`, summary sentence, inverted assisted axis); `lib/src/ui/exercise_progress_chart.dart` (CustomPainter, palette only, range chips via `EquipmentChip`, `kTooFewForTrend` under 3 sessions). Exercise history: Progress, Best at, Sessions. `subflows/log_bench_workout.yaml` ROW is now a regex so it works for a returning lifter.
- Slice 5: `test/history_calendar_stats_test.dart` (13). `derived.dart`: `kStreakGapDays`, `streakChains`, `streakFromDays` (core of `streakAsOf`), `streakLinkedDays`. New `lib/src/data/history_stats.dart` (`historyStatsProvider`, `monthTotalOf`). Root: stats row (Day streak / Workouts / Sets + explainer dialog, `docs/04` copy). Calendar rewritten: clock = `planTodayProvider` (resume-refreshed, B15), rows = weeks in month with `AnimatedContainer` (motion-aware), 48pt chevrons and cells, "This month", month total, weekday header excluded from semantics, full spoken day labels, future "not yet" and inert, pressed feedback, up to 3 dots, neutral today ring, grey streak-run connector, `onLogPastDay` hook for slice 6. Empty copy says "workout".
- Slice 6: `test/history_find_act_test.dart` (12). All workouts: search (title, exercise, note; `searchFold`), muscle chips (`EquipmentChip`), `ListView.builder`, month headings with counts, "No workouts match.". Rows: `ConsumerWidget`, swipe left to delete (delete in `confirmDismiss`, return false), VoiceOver "Delete" custom action, pressed dimming, quiet grey "PB" with no count (slice 7 item, done here). `HistoryExercise.note`. `ActiveSession.startAdHoc(performedOn:)`, `addSavedExercise`. `session_entry.dart`: `startBackfill`, shared `_closeOpenWorkout` (Do again uses it too). Root: empty state "Start a workout" (selects Workout tab), calendar empty past day → "Log a workout for Tue 3 Nov?" → backfill. Editor: Add exercise. Flow 11's row label now "personal best" without a count.
