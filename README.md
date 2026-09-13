# turtle-lift

A workout logging app. Offline, local-only, no login, no cloud, no ads.

Log a set. That's it.

---

## What this repo currently is

**Specification, validated data and prototypes.** No Flutter code yet. Everything here
exists so the build can start without re-deciding anything.

| Path | What |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Project instructions. Claude Code reads this automatically. |
| [`docs/00-build-spec.md`](docs/00-build-spec.md) | Terse rules, tables, file paths. **Start here.** |
| `docs/01`–`04` | Scope and the reasoning behind every rule. These win any conflict with `00`. |
| [`docs/05-mascot-brief.md`](docs/05-mascot-brief.md) | The turtle. Last thing to build. |
| `assets/body-diagrams/` | 4 traced SVGs, muscle taxonomy, and the diagrams as Dart point data. |
| `assets/exercises/` | 260 exercises with setup / posture / execution / common mistakes. |
| `prototypes/` | Three browser prototypes. Open them; nothing to install. |

## The shape of it

Three tabs — **Workout**, **Muscles**, **Profile**.

- Start from a template or go ad-hoc, log sets, finish. Muscle diagram fills in live as
  you work.
- Browse exercises by muscle, or search.
- History, streak, personal bests.

**Nothing derived is stored.** Streak, set counts, personal bests, the muscle ticks and
session titles are all computed on read, because sessions stay editable and deletable
forever. That decision drives most of the data model — see `docs/01` §Derived values.

## Data, and how to keep it honest

Two generators with validators attached. Both fail loudly rather than drifting quietly.

```bash
cd assets/body-diagrams && python3 generate_muscle_taxonomy.py    # 12 groups, 19 sub-groups
cd assets/body-diagrams && python3 generate_body_paths.py          # 4 assets, 42 segments
cd assets/exercises      && python3 validate_exercise_library.py   # 260 exercises, 0 errors
```

Never hand-edit `muscle_taxonomy.*`, `body_paths.dart`, `exercises.json` or
`exercises.csv`. Edit the generator source and re-run.

Wire all three into CI.

## Getting started

```bash
flutter create --org dev.indresh --project-name turtle_lift .
claude                 # then: "read CLAUDE.md and docs/00-build-spec.md"
```

Build the data layer and the set-logging screen first. That one screen exercises every
hard decision at once — four load types, derived values, prefills, personal bests. If the
model survives it, the rest is assembly.

## Explicitly not in V1

No login · no cloud sync · no rest timer · no workout duration · no notifications · no
wearables · no AI · no premium tier · no ads · no multi-day splits · no achievements,
badges or level-ups.

## Health content

`assets/exercises/` contains form instructions. **It carries real injury risk and must
not be rewritten or regenerated without review by someone who lifts.** Review it in
`exercise_library.xlsx`, which is split by muscle group for that purpose.
