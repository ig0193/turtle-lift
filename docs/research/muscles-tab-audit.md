# Muscles tab: audit and production plan

Date: 2026-11-09. Branch audited: `taste-pass-production-polish` at `a494edf`, detached in a worktree. Nothing in the app was changed.

> **Progress note.** Done: docs read, code read, device pass on iPhone 17e (seeded debug build, plus normal and largest text size), spot check on iPhone 17 Pro Max, competitor research, plan.
> **Not driven on a device:**
> - The empty `TURTLE_NO_SEED` build. The tab reads no history by design (`00` §10), so its landing is the same with or without data. That was checked in code, not on screen.
> - Reduce Motion. Checked in code: `exercise_demo.dart` uses `prefersReducedMotion` and does not autoplay.
> - The VoiceOver audit used the accessibility tree from Maestro `hierarchy`, not VoiceOver itself.
>
> Screenshots are in `/private/tmp/claude-501/-Users-heera-Desktop-Dev-turtle-lift/715c8386-c38a-4220-9a7a-ef3a449b043a/scratchpad/muscles-audit/` (files `m01`–`m41`; the `s_`-prefixed copies are downscaled). That folder is session scratch, so copy any shot you want to keep.

---

## Verdict

**Not production ready yet, but close. No crashes and no data bugs.** Every route works:
- map tap to a list, plus the front delt / side delt sheet;
- the 19-row list;
- search across the three vocabularies;
- detail, with its demo, muscles, reviewed copy, substitutes and Add to current workout.

The map's hit-testing is correct at every segment centre I tapped, on both views.

**What blocks it:**
1. **Search misses the most obvious queries.** "shoulders" returns *Nothing matches*, because no sub-group label contains it. The same happens with "legs", "arms", "core", "pecs", "delts" and "calf" (as a muscle). Typos such as "bech press" find nothing. See B1.
2. **The body map is invisible to VoiceOver.** The map has no semantics node at all, so the tab's main visual does not exist for a screen-reader user. The list is still there as a fallback. See B2.
3. **Copy and taste violations on a core surface.** The two-muscle sheet's header is tracked capitals and uses jargon: "THIS SEGMENT CARRIES 2 MUSCLES" (B3). Tapping Add to current workout twice says "added" twice (B4).
4. **The map says nothing about the user.** I logged a Push day today, and the Muscles map is still all grey. This follows the spec (`00` §10: "nothing in it reads session history … deferred"). But it is the biggest experience gap against every competitor that has a map. It also misses `unslop-audit.md`'s direction that the body map is the app's "moment". **Lifting the deferral is a user decision** (Q1).

Items 1–3 are S/M fixes. Item 4 is the one product decision that turns the tab from a reference page into a reason to open it.

---

## Bugs found

| # | Sev | Bug | Repro | Where | Shot |
|---|---|---|---|---|---|
| B1 | **High** | Search has no parent-group or synonym matching and no typo tolerance. "shoulders" shows *Nothing matches "shoulders"*, then the fallback lists. "legs", "arms", "core", "pecs", "delts", "calf" (muscle), "hip" (no Glutes result) and "bech press" fail the same way. Muscle matching is a raw `label.toLowerCase().contains(needle)` against the 19 sub-group labels, and it does not even use `searchFold`. Word order matters: "press bench" finds nothing. | Muscles → search → type `shoulders` | `lib/src/ui/muscle_search_screen.dart:125` (muscle match), `:128` (equipment); `lib/src/data/exercise_index.dart:91,179` (name match is a substring of the whole query) | m12, m41 |
| B2 | **High** (a11y) | The body diagram exposes no semantics, so the Maestro tree jumps from the Front/Back buttons straight to the tab bar. On detail the diagrams are also absent, though the chips carry the information there. VoiceOver users cannot learn that the map exists or which view it shows, and cannot use it. | Muscles tab → `maestro hierarchy` | `lib/src/ui/body_diagram.dart:193` (GestureDetector with no `Semantics`) | m01 + tree |
| B3 | Med | The two-muscle sheet header is tracked capitals and says "THIS SEGMENT CARRIES 2 MUSCLES". That breaks turtle-taste's "sentence case, never tracked capitals", and "segment" is implementation language. | Front view → tap the front shoulder | `lib/src/ui/muscle_segment_sheet.dart:155` | m07, m31 |
| B4 | Med | Add to current workout is not idempotent in what it tells the user. A second tap shows "Barbell curl added" again, although `addExercise` returns the existing row, and the button never changes to show the exercise is already in the workout. | Start a workout → Muscles → Barbell curl → tap Add twice | `lib/src/ui/exercise_detail_screen.dart:164-180`; `lib/src/data/active_session.dart:231` | m23, m24 |
| B5 | Med | The landing map is sized to the full width: 670pt tall on the 17e, more on the Pro Max. The calves and feet sit under the floating tab bar. The hint line ("Tap a muscle, or pick from the list below") and the whole list are below the fold on first paint. The calves cannot be tapped until you scroll. A tap at the back-view calf centre (141,749) landed on the tab bar's edge. | Muscles tab, 17e and Pro Max | `lib/src/ui/muscles_root.dart:105-114` (the `BodyDiagram` has no height cap) | m01, m09, m40 |
| B6 | Low-Med | Several tap targets are below 44pt, and there is no tolerance. The upper, mid and lower chest bands are each about 21pt tall. Front-view traps are about 27×19pt, back-view upper back about 23pt tall. Hit-testing is exact `Path.contains`, so a tap just off a diagonal forearm or a thin band does nothing, with no feedback. | Front view → tap just outside the forearm edge | `lib/src/ui/body_diagram.dart:489`; sizes measured from `body_paths.dart` at 17e scale | m06 |
| B7 | Low | The demo's semantic label says ", paused" when it has finished its three cycles and is resting. It was not paused. | Open any detail, wait about 10 s, read the tree | `lib/src/ui/exercise_demo.dart:97-98` | tree |
| B8 | Low | The editable search field loses its accessible name once you type. The tree shows only the value ("bench"), with no "Search" label. | Search → type | `lib/src/ui/muscle_search_field.dart` (the editable variant relies on `hintText`) | tree |
| B9 | Low | Demo legibility. On barbell curl and decline bench the side-view plate covers the arm and torso, so the movement is hard to read. This adds to the known weak spots in `exercise-animations.md` §next steps: machine levers that look like cables, a cramped deadlift bottom, the decline leg hook, the overhead-press head hiding the elbow. | Detail → Barbell curl; Decline barbell bench press | `lib/src/demo/` per-pattern | m16, m24 |
| B10 | Low (docs) | The docs contradict each other and the code. Per CLAUDE.md, report rather than pick. | — | — | — |

B10 in detail:
- `03` "Screen list" item 4 says *no "Add to current workout"* (line 114), and line 134 says the add confirmation is deferred. Both are built, and line 98 of the same file says so.
- `03`/`00` §10 say the Exercise history screen is "deferred … no reachable entry point". It is built (`exercise_history_screen.dart`) and reachable from set logging, but not from exercise detail.
- `00` §5 says to label the front shoulder **"Shoulder (front)"**, not "Front delt". The taxonomy and the UI say "Front delt" everywhere.

**Checked and fine:**
- All segment centres on both views open the right list: chest ×3, front traps, forearms, obliques, front delt (sheet), back upper, rear delt, triceps, glutes. Mid chest was checked through the 15-exercise list.
- Head and neck taps do nothing, which is correct.
- Dismissing the sheet opens nothing.
- At the largest text size (clamped to 1.3x) the layout holds. Only the search placeholder truncates ("Search exercises, muscles, …").
- Side delt's detail paints the front-shoulder segment, as the mapping rule says.
- Custom exercises are merged into `exerciseIndexProvider`, so they appear in lists and search (ADR 0009, checked in code).

---

## UX/UI findings by screen

**Landing (m01–m03, m09, m40)**
- **No moment.** It is a grey figure, and a workout logged today changes nothing (see Verdict 4). The press label and the amber commit flash are nice, but they last 450 ms.
- The map takes the whole first screen, and the list (the route that works for VoiceOver and for small muscles) starts about 1.3 screens down. Competitors that use a map as a filter keep it compact. StrengthLog's is a "small body image" [13].
- "All 19 sub-groups" is taxonomy language, and the list is flat with no parent headings, so Chest, Back, Shoulders and so on are not scannable.
- There is no personal entry point: no recently viewed, no "your exercises", no last trained. StrengthLog and Alpha Progression default to the user's own most-used or recent exercises [13][15].
- Front/Back as two 48pt capsules is clear and correct.

**Two-muscle sheet (m07)**
- The header copy and caps (B3). It does not show which muscle you tapped while it is open, because the commit fill clears.

**Exercise list (m04)**
- 9–26 rows with name and equipment only. There is no equipment filter, although equipment is the one filter every app with filters shares [1][3][8][13][15].
- Order is catalogue order, not grouped or sortable.
- Custom exercises are not marked as yours.
- There is no "done before / last time" hint. It is deferred in `03`, and it is cheap to derive.

**Search (m11–m15, m41)**
- B1 is the main problem.
- Results are ordered by kind (muscles, then equipment, then exercises), not by relevance. "bench" lists six exercises, which is fine.
- The fallback (full muscle and equipment lists on no match) is good. It just fires far too often.
- No recent searches.

**Exercise detail (m16–m20, m22–m24, m33)**
- Good order: facts, demo, muscle chips with the diagram(s), action, reviewed copy with Common mistakes open, substitutes rail.
- There is no history link even when you have logged the exercise. The history screen exists and is only reachable from set logging. Hevy has a History tab per exercise [7], and Fitbod's map tap opens a muscle's history [4].
- With no workout open there is no action at all. "I found it, now do it" ends here, with no "Start a workout with this". (`03` deliberately says reference-only; this is Q3.)
- The snackbar is a default Material full-width chalk bar that covers the Common mistakes header (m24).
- "Weighted" in the facts line is a load-type term. "Barbell · Weighted" reads oddly, and "Barbell · Weights" or just "Barbell" would read better.

**Accessibility**
- B2, B7, B8.
- Rows, chips, buttons and the sheet are well labelled ("Biceps. 18 exercises", "Primary muscle: Lower chest Also works: Triceps …").
- The chips label would read better with punctuation between groups.

---

## Competitors (8)

Primary sources. *(idx)* means the page returned 403 to a direct fetch and the claim comes from the search engine's index of that same URL. Gymverse was swapped for Muscle & Motion: Gymverse's listing is an AI trainer with no body map [18], while M&M is an anatomy-first library with a common-mistakes series, the closest match to TurtleLift's detail page [16][17].

| App | Find by muscle | Body map | Exercise detail | Filters | Standout |
|---|---|---|---|---|---|
| **MuscleWiki** | The interactive body map is the main route [1]. Browse muscle → equipment [2 (idx)] | Navigational: tap a muscle for its exercises [1]. A volume or recovery overlay is not verified | Video for 1,600+ exercises [1] | Equipment and muscles [1][2 (idx)]. Difficulty not verified | Offline exercise library marketed as a feature [1] |
| **Fitbod** | Search by muscle group, equipment or keyword [3] | Recovery avatar: rotate front/back, tap a muscle for its history, edit recovery % by hand [4 (idx)][5 (idx)] | Multi-angle video and written instructions [3] | Muscle, equipment, keyword [3] | A modelled value the user can correct and trace back [4 (idx)] |
| **Hevy** | Library with equipment and muscle filters [8 (idx)] | "Last 7 days" body graph. Body distribution shows **sets per muscle** for the calendar week, step through weeks [6] | How-to opens mid-workout. History tab. **Records follow the load type** (reps for bodyweight, time for timed) [7] | Equipment, muscle, search [8 (idx)]. Custom exercises have the same fields [9 (idx)] | Countable sets over a labelled window [6] |
| **JEFIT** | BodyMap from a routine. "+" adds an exercise for a gap [10] | Distribution % per muscle and sub-muscle, planned vs actual. Recovery chart, weekly sets [10][11] | HD video and animations, 1RM, progress charts [11] | Library filters not verified [11] | The map leads to an action (fill the gap) [10] |
| **Strong** | Muscle filter not verified [12] | None in the listing [12] | Animated instructions. PRs, 1RM and volume graphs [12] | Not verified [12] | Pure logger: detail and records carry it [12] |
| **StrengthLog** | Defaults to **most-used**. Tap a small body image to filter "without knowing the name" [13] | A filter, plus a per-exercise muscle map [13][14] | Video, steps, muscle map, reached with "?" while logging [14] | Equipment (long-press = only this), standard vs own, sort A–Z or most-used [13] | One-gesture "only this equipment" [13] |
| **Alpha Progression** | Muscle, equipment and compound/isolation filters. "Recently performed" sort, usage count [15] | None. Sets per muscle in charts [15] | Real-gym video, setup, execution and cues [15] | Muscle, equipment, **mechanics** [15] | The library is personalised (usage count on the list) [15] |
| **Muscle & Motion** | Area → sub-area filter, movement pattern, search [16] | Rotatable 3D model, recently viewed muscles [16] | Prime/synergist/stabiliser colour coding, **common mistakes**, emphasis changes, alternatives one tap away [16][17 (idx)] | Area, sub-area, movement pattern [16] | Mistakes taught as content in their own right [16][17] |

**Principles to take from these.** Behaviour only: not looks, names, artwork or layout signatures.
1. Two ways in, one destination: map for people who don't know the name, search and list for people who do [1][13].
2. Open on the user's own exercises, recent or most-used, derived on read [13][15].
3. Equipment is the filter that matters, and "only this" should be one gesture [13].
4. When a map shows training, show **countable sets over a labelled window**, or a "last trained" date. Avoid a modelled recovery % [6][10][4].
5. A map tap should lead somewhere useful: exercises, history, add [10][4].
6. Detail is reachable mid-session, and history and records follow the load type [7][14].
7. Custom exercises are first-class, with a "mine vs standard" view [9][13].
8. Alternatives sit one tap from detail [16]. TurtleLift already does this.

Sources:
- [1] https://apps.apple.com/us/app/musclewiki-app/id1096827640
- [2] https://musclewiki.com/exercises
- [3] https://apps.apple.com/us/app/fitbod-workout-gym-planner/id1041517543
- [4] https://help.fitbod.me/hc/en-us/articles/360006269014-Muscle-Recovery
- [5] https://fitbod.me/blog/muscle-recovery/
- [6] https://www.hevyapp.com/features/muscle-group-workout-chart/
- [7] https://www.hevyapp.com/features/exercise-performance/
- [8] https://help.hevyapp.com/hc/en-us/articles/35688251991575-Hevy-Exercise-Library-400-Exercises-and-Custom-Exercises
- [9] https://help.hevyapp.com/hc/en-us/articles/35700328894103-How-to-Create-Custom-Exercises-in-Hevy
- [10] https://www.jefit.com/blog/introducing-bodymap-a-smarter-way-to-visualize-your-training
- [11] https://apps.apple.com/us/app/jefit-workout-planner-gym-log/id449810000
- [12] https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577
- [13] https://help.strengthlog.com/?p=1673
- [14] https://www.strengthlog.com/workout-log-with-exercise-instructions/
- [15] https://apps.apple.com/app/id1462277793
- [16] https://apps.apple.com/us/app/id1302056349
- [17] https://muscleandmotion.com/strength-training-app
- [18] https://apps.apple.com/us/app/1048454034

---

## Prioritised improvements

Effort: S is under half a day, M is 1–2 days, L is 3 days or more. "Decision" means the item needs a yes from you first.

| # | What | Why | Where | Effort | Decision |
|---|---|---|---|---|---|
| 1 | **Search: muscle vocabulary.** Match parent groups and common synonyms to sub-groups, all through `searchFold`. Shoulders/delts/delt → the three delts. Pecs → chest ×3. Legs → quads, hamstrings, glutes, calves. Arms → biceps, triceps, forearms. Core → abs, obliques. Calf → calves. Hip → glutes. Traps → upper back. The synonym table lives in Dart next to the search code, not in the generated taxonomy. | B1. Principle 1 | `muscle_search_screen.dart`, new `muscle_synonyms.dart` | S | Approve the synonym list |
| 2 | **Search: token AND match plus light typo tolerance.** Every query word must appear in any order. If nothing matches, fall back to edit distance ≤1 on words of 4+ letters, labelled "Did you mean …". | B1 ("bech press", "press bench") | `exercise_index.dart:91,179` | S–M | No |
| 3 | **Body map semantics.** One container label per view ("Body map, front. 12 muscles. Use the list below to choose one."). Optionally a semantics child per segment with `onTap`, using the rects of the cached paths. | B2 | `body_diagram.dart` | S (container) / M (per segment) | No |
| 4 | **Sheet copy.** "Which shoulder muscle?" in sentence case, using `kLandingSectionLabelStyle`. Keep the selected segment filled while the sheet is open. | B3, turtle-taste | `muscle_segment_sheet.dart:155`, `body_diagram.dart` | S | No |
| 5 | **Add-to-workout state.** If the exercise is already in the open session, show "In your workout" (disabled or outlined) and the toast "Already in your workout". Use the app's styled toast, not the default SnackBar. | B4. `03` line 134 asks for "a button state change" | `exercise_detail_screen.dart:160-180` | S | No |
| 6 | **Fit the map on screen.** Cap the landing diagram's height so the whole figure and the hint sit above the tab bar on a 17e. The list's first row should peek out. | B5. Principle 1 (the list is a first-class route) | `muscles_root.dart` | S | No |
| 7 | **Tap tolerance.** If `Path.contains` misses, pick the nearest segment within about 12pt, using cached bounds and distance to the edge. Give a selection haptic on press. Test thin bands and diagonal forearms. | B6. 44pt guideline | `body_diagram.dart:480-490` | M | No |
| 8 | **Derived training view on the map.** Fill sub-groups trained in a labelled window: amber for primary sets, steel for secondary, read from `SetEntry`, computed on read. A tap's sheet or list header shows "Last trained 3 days ago · 9 sets this week". Facts only, no recovery model. | Verdict 4. Principles 4 and 5 [6][10]. unslop "moment". Fill is already a caller parameter | `muscles_root.dart`, new derived provider beside the session store, the exercise list header | M–L | **Yes**: lifts the `00` §10 / `03` deferral; also pick the window (this week vs last 7 days) |
| 9 | **Exercise history link on detail.** When the exercise has been logged: one line, "Last: 22kg × 10 · 14 times · See history", into the existing `ExerciseHistoryScreen`. Keep the load-type formatter and the inverted assisted record. | Principle 6 [7]. The screen is already built | `exercise_detail_screen.dart`, `exercise_history_screen.dart` | S–M | **Yes**: `03` says detail has no history block |
| 10 | **Equipment filter on exercise lists.** Chips for the equipment values present in that list (outlined; selected = amber border), plus "Clear". Session-only, never stored. | Principle 3 [13][15] | `muscle_exercise_list_screen.dart` | M | Light yes: `00` §10 calls the equipment list "a search destination only" |
| 11 | **Group the landing list under parent headings** (Chest, Back, Shoulders …) and rename "All 19 sub-groups" to "Muscles". | Scannability, plain language | `muscles_root.dart`, `sub_group_row.dart` | S | No |
| 12 | **"Last done" hint on list rows** (`Last: 22kg × 8`), derived. Mark custom exercises "Yours". | Deferred in `03`. Principles 2 and 7 | `ExerciseRow` | S–M | Yes (same deferral as #8 and #9) |
| 13 | **Demo polish pass.** Fix plate occlusion of the arm/torso on the barbell curl and bench family. Also fix the known weak spots: machine levers, deadlift bottom, decline leg hook, overhead-press elbow. Review the remaining 14 of 22 contact sheets. | B9. ADR 0011 next steps | `lib/src/demo/` | M–L | No |
| 14 | **Demo label wording.** At rest say "Demonstration of X" (no ", paused"). Use ", paused" only after a user pause. | B7 | `exercise_demo.dart:97` | S | No |
| 15 | **Search field accessible name** when it has text ("Search, bench"). Recent searches (in memory only) on the empty state. | B8, speed | `muscle_search_field.dart`, `muscle_search_screen.dart` | S | Recents: no (not persisted) |
| 16 | **Relevance order in search.** Exact or prefix name matches first, then muscles, then equipment, then contains-matches. | B1 follow-on | `muscle_search_screen.dart` | S | No |
| 17 | **Start from detail when no workout is open.** A secondary "Start workout with this" opens a session with this exercise. | Dead end on detail. Principle 5 | `exercise_detail_screen.dart`, `session_entry.dart` | S | **Yes**: `03` says the reference page offers no way into a workout |
| 18 | **Docs reconcile.** Fix `03` line 114 and 134, `03`/`00` on Exercise history, and `00` §5 "Shoulder (front)" vs "Front delt". | B10 | docs | S | Yes: which label wins |

**Later, or in conflict with CLAUDE.md scope. Do not build in V1.**
- A recovery % model, or "ready to train" readiness. That is a modelled value, not a derived fact, and needs a product call even if computed on read.
- Planned-vs-actual coverage per template (JEFIT style). It belongs to the Workout tab.
- Sharing the muscle map. That is social; the summary card already covers it.
- AI suggestions to fill gaps. AI is out of scope.
- Video or photographic demos. They break offline size, and ADR 0010 already chose drawn demos.
- Rotatable 3D anatomy. It breaks "one diagram treatment everywhere" (`00` §5).
- A difficulty filter. No competitor had one verified, and the data has no difficulty field.
- Duplicate a built-in exercise into a custom one. Useful (Hevy [9]), but it would have to copy reviewed copy into a custom row, which ADR 0009 forbids. It is only possible if custom rows keep no content.

---

## Build order (slices)

Each slice: tests first, then a Maestro flow under `.maestro/flows/` (next numbers 17+), run by `tool/maestro_run.sh` on the 17e and the Pro Max, and taste shots via `tool/taste_shots.sh`.

1. **Search quality (#1, #2, #16, #15a).**
   - Unit tests in `test/muscle_search_test.dart` / `qa_search_test.dart`: table-driven queries. "shoulders" returns 3 delts. "legs", "pecs", "calf", "hip", "press bench", "bech press" (did-you-mean). Ordering of exact before contains. Custom exercise names are found.
   - Maestro `17_muscles_search.yaml`: type each query and assert the first result's label.
2. **Copy, state and a11y quick wins (#3 container, #4, #5, #14, #15 label).**
   - Widget tests: sheet header text and no caps (extend the taste guard). Second Add shows "Already in your workout" and the button state. Demo label at rest. `BodyDiagram` exposes a semantics label per view. The search field label persists with text.
   - Maestro `18_muscles_a11y.yaml`: assert the "Body map, front" node, flip to Back and assert the label, tap Add twice and assert the copy.
3. **Map ergonomics (#6, #7, #3 per-segment).**
   - Widget tests: on a 375×667 and a 390×844 surface the diagram plus hint fit above `screenScrollPadding` bottom. `segmentAt` resolves points 8pt outside the forearm and the chest bands to the nearest segment, and points 30pt outside to null.
   - Maestro `19_muscles_map_taps.yaml`: tap every segment centre and near-edge on both views (coordinates from `body_paths.dart`), assert each list title, and the calves without scrolling.
4. **List structure and filters (#11, #10).**
   - Widget tests: parent headings in taxonomy order, 19 rows still reachable. Equipment chips derived from the list, filter state not persisted (rebuild resets).
   - Maestro: Glutes → filter Machine → assert the count.
5. **Derived training view (#8, #9, #12): after the decision.**
   - Unit tests on the provider: sets per sub-group for the window; secondary counted separately. Editing or deleting a session changes the map (no stored aggregate). `performedOn` boundaries at 23:00 and in the DST zone. An assisted record stays inverted in the "Last/Best" line. A custom exercise's muscles count.
   - Widget tests: fill colours from §12 only (`theme_palette_test`).
   - Maestro `20_muscles_trained.yaml`: an empty install shows a grey map; log 2 sets of curls; the Muscles map fills biceps; the list header says "Last trained today · 2 sets"; delete the session and the map is grey again.
6. **Detail start action (#17): after the decision.**
   - Widget test: the entry matrix (`exercise_detail_entry_test.dart`).
   - Maestro: no session → detail → Start → the session has that exercise.
7. **Demo polish (#13).** Contact-sheet review of all patterns. Extend `test/exercise_demo_test.dart` with an occlusion check (the hand joint is not inside a plate's circle at peak) where feasible.
8. **Docs (#18)** once the decisions are in.

---

## Open questions for you

1. **Should the Muscles map show your training** (#8)? This lifts the `00` §10 / `03` deferral. If yes: is the window "this week (Mon–Sun)" or "last 7 days"? And does it show sets per muscle, a "last trained" date, or both?
2. **History on exercise detail** (#9): one "Last · Times · See history" line when logged, nothing when not?
3. **A way to start a workout from detail** when none is open (#17), or keep detail reference-only?
4. **Equipment filter chips on exercise lists** (#10): this changes `00` §10's "search destination only" rule for equipment.
5. **The synonym list for search** (#1): approve it, or edit it.
6. **Front shoulder label**: "Front delt" (what ships) or "Shoulder (front)" (`00` §5)?
