# CLAUDE.md

Flutter workout-logging app. Offline, local-only, no login, no cloud.

## Read this first

`docs/00-build-spec.md` — terse rules, tables and file paths. Start here.

Read `docs/01`–`04` only when you need the reasoning behind a rule, or when `00`
doesn't cover something. **If `00` disagrees with `01`–`04`, `01`–`04` win** —
`00` is a digest, not the source of truth. Report any conflict you find rather
than picking one.

`prototype/prototype.html` — 22 screens, open it in a browser. It is the visual
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
7. Profile tab.

## Still undecided — ask, don't guess

- App display name (splash and share card use a placeholder).
- Whether the ad-hoc overview and the template overview are one widget with a
  variant flag or two separate widgets.
- State management and local database choice. Not specced deliberately — decide
  in session 1 and record the choice here.

## Out of scope for V1 — do not build

No login · no cloud sync · no soft delete · no rest timer · no workout duration ·
no notifications · no wearables · no AI features · no premium tier · no ads ·
no multi-day splits · no per-exercise illustrations ·
no achievements, badges or level-ups.

The turtle mascot (`mascot-brief.md`) is **the last thing to build** — decorative only,
never a body diagram, and it must never react to inactivity. Orientation per surface
(standing vs horizontal), whether it appears on the set-logging screen, and exact sizing
are all deliberately left open in the brief. Settle them against running screens, with
the user, at the end.
