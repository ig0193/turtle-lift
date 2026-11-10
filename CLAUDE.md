# CLAUDE.md

Flutter workout-logging app. Offline, local-only, no login, no cloud.

## Read this first

`docs/00-build-spec.md` — terse rules, tables and file paths. Start here.

Read `docs/01`–`04` only when you need the reasoning behind a rule, or when `00`
doesn't cover something. **If `00` disagrees with `01`–`04`, `01`–`04` win** —
`00` is a digest, not the source of truth. Report any conflict you find rather
than picking one.

`prototypes/screens.html` — 22 screens, open it in a browser. It is the visual
reference and is **ahead of the docs on layout**. Where they differ on how a
screen looks, follow the prototype. Where they differ on a rule, follow the docs.

## Generated data — never hand-edit

| Path | What |
|---|---|
| `assets/body-diagrams/*.svg` | 4 traced body diagrams (male/female × front/back) |
| `assets/body-diagrams/muscle_taxonomy.dart` | 12 parent groups, 19 sub-muscle groups, segment mapping |
| `assets/body-diagrams/body_paths.dart` | The 4 diagrams as point lists — 42 segments, ready to render and hit-test |
| `assets/exercises/exercises.json` | 260 exercises with content, plus each one's demonstration pattern and gear (`animation_map.py`) |
| `assets/foods/foods.json` | Protein food list for Diet, IFCT 2017 values — reviewed nutrition copy (`docs/adr/0007-diet-in-profile.md`) |

Each has a generator and validator alongside it. If a muscle id, exercise or food
needs changing, edit the generator source and re-run it — then the validator
proves nothing drifted. **Wire every validator into CI.** They already catch
orphan segments, unknown muscle ids, and missing content.

## Non-obvious things that will bite

**Rendering the body diagram.** Every path in the four SVGs is a pure `M`/`L`/`Z`
polyline — no curves, no arcs. So do not reach for an SVG library that renders to
an opaque picture: you cannot recolour one segment or hit-test a tap on it.
**This is already done for you: `body_paths.dart` has all 42 segments as point
lists**, with a `toPath()` helper and a usage sketch in its header. Render with
`CustomPainter`, fill per segment, hit-test with `Path.contains`. Segment ids
match `muscle_taxonomy.dart` exactly. Cache the built `Path` objects rather than
rebuilding them each frame. Do not add an SVG rendering package — you do not
need one, and it would give you back an opaque picture you cannot recolour.

**The app bar is pinned on every screen.** Build screens with `AppScreen`
(`lib/src/ui/app_screen.dart`) — `.root` for a tab root, `.pushed` for anything
on the stack. The header is the `Scaffold.appBar`, so it sits outside the body
and cannot scroll; the body *is* the scrollable. Never put a title row inside
the scroll view, and never use `SliverAppBar` with `floating`, `snap` or a
collapsing `expandedHeight` — a header that hides on scroll is not pinned.
`test/app_screen_test.dart` holds the rule. This is a **deliberate override of
the prototypes**, which render `.hdr` / `.l0h` inside `.scroll`; they have been
corrected to `position: sticky` to match, but the Dart widget is the reference.

**Nothing is stored that can be derived.** Streak, set and exercise counts,
personal bests, per-session PB count, calorie estimate, the `trained` tick, and
the resolved session title are all computed on read. Sessions are editable and
deletable, so any stored aggregate goes stale immediately. See `01` §Derived
values before adding a counter anywhere.

**`performedOn` is a local calendar date, not a timestamp.** An 11pm session must
not land on the wrong day. `loggedAt` is a separate internal timestamp.

**Four `loadType` variants, one screen.** `weighted` (196), `bodyweight` (47),
`assisted` (3), `timed` (14). One logging screen with a formatter, not four
screens. Every numeric input is an unsigned positive number — the sign is carried
by the type.

**Assisted PB is inverted.** Less assistance is better. It is the only place in
the app where a smaller number is the record, and it is the thing most likely to
ship backwards.

**Exercise content carries injury risk.** Do not rewrite, summarise, or
regenerate the `setup` / `posture` / `execution` / `commonMistakes` fields. They
are reviewed copy.

## Build order

1. **Data layer + models**, driven by `00` §2. Get `performedOn`, `loadType` and
   the derived-value helpers right before any UI.
2. **The set-logging screen**, all four variants. Do this second, not last — it
   exercises every hard decision at once (load types, prefills, PB computation,
   completed-set rules). If the model survives this screen, the rest is assembly.
3. Body-diagram widget with per-segment fill and tap.
4. Workout flow: landing → template picker → overview → exercise list → logging.
5. Summary and celebration.
6. Muscles tab.
7. History tab.
8. Profile tab — fourth tab, Personal | Schedule
   (`docs/adr/0004-profile-returns-as-a-tab.md`), then the Schedule screen and
   reminders (`docs/adr/0005-schedule-and-opt-in-notifications.md`, notifications last).
9. Diet — third Profile segment, a protein-only weekly plan
   (`docs/adr/0007-diet-in-profile.md`, plan in
   `docs/plans/2026-11-08-1702-feat-diet-weekly-protein-plan.md`). After
   Profile/Schedule, before the mascot; diet reminders only after the ADR 0005
   notification infrastructure exists.

## Decided in session 1

- **State: Riverpod** (`flutter_riverpod`, no codegen). Everything user-visible is
  derived on read, so derived values are computed providers that invalidate
  themselves — no manual refresh path to forget when a session is edited.
- **Storage: Drift over SQLite** (`drift` + `drift_flutter`). Relational shape
  matches Session → SessionExercise → SetEntry, and per-exercise history stays a
  query rather than a full-table scan in Dart. Codegen via `build_runner`.
- **iOS integrates plugins through Swift Package Manager, not CocoaPods.** CocoaPods
  cannot install on the system Ruby here. Nothing to do — just do not add a
  plugin that ships no `Package.swift`.
- Generated Dart (`muscle_taxonomy.dart`, `body_paths.dart`) is copied into
  `lib/src/data/generated/` by `tool/sync_generated.sh`, because Dart can only
  import from `lib/`. Both copies are generated output: edit the generator, re-run
  it, then re-run the sync. `tool/sync_generated.sh --check` guards this in CI.
- ~~`lib/main.dart` renders a placeholder `SetupCheckScreen`~~ **Done.** The
  placeholder is deleted and `main.dart` boots into `L0Shell`. The data it read lives
  in `lib/src/data/`, not in `main.dart`, so deleting the screen took nothing
  with it.
- **Bundle id: `dev.indresh.turtle_lift` (Android) / `dev.indresh.turtleLift` (iOS).**
  The casing differs because that is what each platform's tooling produces from one
  `--org dev.indresh`, which is the org `README.md` specified from the start. It is
  **permanent from the first store upload, including internal test tracks** — the
  scaffold had shipped `com.example.*`, which Play rejects outright, and it was
  corrected before any upload.
- **App display name: `TurtleLift`.** One word. It is the wordmark on the
  summary card, which is built to be screenshotted, so it could not stay a
  bracketed placeholder.
- ~~The two overview paths are two widgets, not one with a flag.~~ **Superseded
  by `docs/adr/0006-workout-tab-is-exercise-first.md`.** A session is a list of
  exercises; a template is a pre-filled one and ad-hoc is an empty one, so there
  is one session screen (`SessionOverviewBody`) and nothing left for two
  overviews to disagree about. Templates store exercise ids, not muscle groups;
  there is no split filter, no nested muscle list, no `trained` tick and no
  template lock. Muscles are shown only by the live body map.
- **The Workout tab starts on a ready view.** Start opens the session with one
  **Start logging** button; the exercise picker is a sheet over the map, and the
  list appears only after it. "Started logging" is held in memory
  (`loggingStartedProvider`), never stored.
- **The live clock is display-only.** `sessionClockElapsed` derives it from
  `loggedAt`; it is never stored and is shown nowhere but the live screen, and
  only for a session dated the day it started and under six hours old.
- **Schema is at version 9.** Step 9 adds `custom_exercises.hidden` (Hide from
  picker, for a logged custom exercise that cannot be deleted) and
  `session_exercises.note` (one note per exercise per workout; the "Last time"
  hint is derived) — `docs/adr/0011-combined-build-decisions.md`, which also
  records swap in place and the deferred kg/lb, warm-up sets and supersets.
  Step 8 is `custom_exercises`, the user's own
  exercises (`docs/adr/0009-custom-exercises-and-template-editing.md`): ids always
  `custom-…`, no content fields ever, one merged index (`exerciseIndexProvider`;
  the boot override is `libraryIndexProvider`).
  Previously: schema version 7. Step 6 adds the diet tables (`DietPlanVersions`,
  `DietPlanItems`, `MealTicks`, `Settings.proteinTargetG`); step 7 adds
  `ReminderPrefs` (ADR 0007). Step 5 gives a custom template its `exercise_ids`;
  the old `group_ids` columns on `custom_templates` and `sessions` stay, unwritten
  and unread, because SQLite cannot drop them without rebuilding a table that
  holds user data. The drift output (`app_database.g.dart`) is committed; re-run
  `dart run build_runner build` after any change to the tables.
- **Session tables took the reserved schema version 2.** The personal-details
  work landed at 3 and numbered around the gap deliberately. That only worked
  because nothing had shipped: a device already at 3 never runs the reserved
  step, so a development install from before it has to have its data cleared
  once. **No later step may be numbered below the current version.**
- **A muscle fills on the map on a completed set as well as on Mark exercise
  done.** A user who logs three sets and walks to the next machine has trained
  it. (There is no tick list any more — see above.)
- **Palette is Chalk & Shell** (`docs/research/unslop-audit.md`): graphite neutrals
  (`#0E0E0F` page), shell amber `#FFA53D` for trained / active / selection / PB, steel
  `#93ABCB` for the secondary muscle only. **The primary button is a chalk capsule**
  (`#EDEDEB` fill, dark label), one per view; secondary actions are text. **No
  gradients.** One PB mark everywhere: the word "PB" in amber, no pill, no trophy.
  Role names in `AppPalette` are unchanged from the earlier palettes.
- **Taste pass (turtle-taste skill, `.claude/skills/turtle-taste/`).** Labels
  are sentence case, never tracked capitals; no text under 12pt; `textMuted` is
  `#8B8B90` (4.5:1 or better on every surface); one type scale (12 / 13 / 15 /
  17 / 20 / 24, `AppTypeScale`), no tracking below 16pt; one radius scale (16
  cards and fields, capsule buttons and chips; tags and statuses are text, not
  pills); selection controls are outlined, only the primary action is filled. System text size is honoured up
  to 1.3x (`main.dart`); the set-logging number ignores it and fits its box.
  `tool/taste_shots.sh` screenshots every screen on a small and a large iPhone.
- **Export and Delete all data are built** (`lib/src/ui/data_screens.dart`).
  Export writes entered data only (nothing derived) as JSON and opens the
  share sheet via `share_plus` + `path_provider` (both ship `Package.swift`).
  Delete wipes every table in one transaction, then re-runs boot through
  `appRestartProvider` so no notifier keeps deleted state; the debug sample
  seed is not re-run after a wipe.
- **Destructive actions use `#FF7A85`,** the eleventh palette colour (`00` §12,
  `01` §Usage rules). The accent `#FFA53D` could not carry "delete": it means "active / this
  has been worked" *"wherever it appears"*, so a delete confirmation painted in it
  reads as approval. `test/theme_palette_test.dart` fails on any colour outside §12.
- **The week lives on the Workout landing** (`docs/adr/0008-the-week-lives-on-the-workout-landing.md`,
  amends 0004 and 0005). Profile › Schedule holds only the plan (days, reminder);
  the derived "this week" strip and a "last workout" line sit above the landing's
  search, and a training reminder opens the Workout tab (payload string still
  `schedule`). Planned muscles are outlined in `textSecondary`, never amber or
  steel. Sharing the summary card as an image (system share sheet), "Do again",
  the folding Ready-made grid, haptics (`AppHaptics`), the pinned Mark exercise
  done bar, last time in each set row and the live PB mark are all in 0008.
- **iOS Live Activity + home-screen widget** (ADR 0008 §7): one method channel
  (`glance_bridge.dart` ↔ `ios/Runner/GlanceChannel.swift`) and the
  `ios/TurtleLiftWidgets` extension target (iOS 17+, App Group
  `group.dev.indresh.turtleLift`). No plugin. The activity's clock is a system
  timer from the session start; nothing is stored.
- **Profile has three segments: Personal | Schedule | Diet**
  (`docs/adr/0007-diet-in-profile.md`, proposed). Diet is a segment, not a fifth
  tab — four tabs stays the ceiling (ADR 0004). The selected segment lives in an
  in-memory `profileSegmentProvider`, never stored: Profile opens on Personal on
  cold start and after Delete all data; a diet reminder tap selects Diet; a
  training reminder tap opens the Workout tab (ADR 0008).

- **Exercise demonstrations are drawn by the app** (`docs/adr/0010-exercise-demonstrations-are-drawn-not-bundled.md`),
  reversing the old "no per-exercise illustrations" scope line at the user's request. An original keyframed
  figure (`lib/src/demo/`) for all 260 exercises, mapped in `assets/exercises/animation_map.py`. **Never bundle
  third-party exercise GIFs/videos** (openGym's are licensed Gym Visual stock; ExerciseDB forbids storage).
  Review the figures with `DEMO_SHEET_DIR=… flutter test tool/demo_sheet_test.dart`.
- **History is also the progress surface** (`docs/adr/0013-history-is-also-the-progress-surface.md`).
  A stats line (day streak, workouts, sets) and a month total on the calendar,
  never the current week; a per-exercise best-set chart (assisted inverted, no
  e1RM) and a quiet "Best at" table on exercise history; streak runs drawn on the
  calendar by `streakChains`. History detail and the editor share one
  `SessionCard`; records come from one cached pass (`personalBestProjection`); the
  title chain is `titleFromParts`; every date goes through `date_labels.dart`
  (year only when not this year in lists, always on the share card). Rows swipe to
  delete; a saved workout can change date and take another exercise; an empty past
  calendar day backfills a workout.

## Still undecided — ask, don't guess
- Typeface. The prototypes use Inter; the app currently uses the platform default.
  If Inter is chosen it must be **bundled as an asset** — the app is offline and
  must not fetch a font at runtime. Genuinely open: do not bundle it without asking.

## Out of scope for V1 — do not build

No login · no cloud sync · no soft delete · no rest timer · no stored workout duration (the live clock is display-only) ·
no notifications (except the opt-in reminders in ADR 0005, built after Schedule, and diet reminders under the same rules, ADR 0007) · no wearables · no AI features · no premium tier · no ads ·
no multi-day splits ·
no achievements, badges or level-ups ·
no calorie, macro or food-diary tracking (no calories, carbs or fat, no free-form food logging, no custom foods).

Diet is a protein-only weekly plan with a daily protein total, and nothing wider
(`docs/adr/0007-diet-in-profile.md`).

The turtle mascot (`docs/05-mascot-brief.md`) is **the last thing to build** — decorative only,
never a body diagram, and it must never react to inactivity. Orientation per surface
(standing vs horizontal), whether it appears on the set-logging screen, and exact sizing
are all deliberately left open in the brief. Settle them against running screens, with
the user, at the end.

## Agent skills

### Issue tracker

Local markdown under `.scratch/<feature>/`, not GitHub Issues — and `.scratch/` is
gitignored, so tickets stay local. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, unchanged, written as a `Status:` line in each issue file.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. Neither exists yet;
that is expected. See `docs/agents/domain.md`.
