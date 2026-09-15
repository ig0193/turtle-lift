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
| `assets/exercises/exercises.json` | 260 exercises with content |

Both have generators and validators alongside them. If a muscle id or exercise
needs changing, edit the generator source and re-run it — then the validator
proves nothing drifted. **Wire both validators into CI.** They already catch
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
8. Profile screen — reached from the header avatar, not a tab
   (`docs/adr/0003-l0-navigation-variant-a.md`).

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
- **The two overview paths are two widgets, not one with a flag.** They share
  the title, date control, body map and Finish/Discard as separate widgets and
  differ only in their list — a nested muscle list against a flat exercise list,
  which answer different questions.
- **Session tables took the reserved schema version 2.** The personal-details
  work landed at 3 and numbered around the gap deliberately. That only worked
  because nothing had shipped: a device already at 3 never runs the reserved
  step, so a development install from before it has to have its data cleared
  once. **No later step may be numbered below the current version.**
- **A muscle ticks on a completed set as well as on Mark exercise done.** A user
  who logs three sets and walks to the next machine has trained it.
- **Destructive actions use `#C4553A`,** the eleventh palette colour (`00` §12,
  `01` §Usage rules). `#D85A30` could not carry "delete": it means "active / this
  has been worked" *"wherever it appears"*, so a delete confirmation painted in it
  reads as approval. `test/theme_palette_test.dart` fails on any colour outside §12.

## Still undecided — ask, don't guess
- Typeface. The prototypes use Inter; the app currently uses the platform default.
  If Inter is chosen it must be **bundled as an asset** — the app is offline and
  must not fetch a font at runtime. Genuinely open: do not bundle it without asking.

## Out of scope for V1 — do not build

No login · no cloud sync · no soft delete · no rest timer · no workout duration ·
no notifications · no wearables · no AI features · no premium tier · no ads ·
no multi-day splits · no per-exercise illustrations ·
no achievements, badges or level-ups.

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
