# turtle-lift

A workout logging app. Offline, local-only, no login, no cloud, no ads.

Log a set. That's it.

---

## What this repo currently is

**Specification, validated data, prototypes, and an empty Flutter app scaffold.** No
screens yet. Everything here exists so the build can start without re-deciding anything.

| Path | What |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Project instructions. Claude Code reads this automatically. |
| [`docs/00-build-spec.md`](docs/00-build-spec.md) | Terse rules, tables, file paths. **Start here.** |
| `docs/01`–`04` | Scope and the reasoning behind every rule. These win any conflict with `00`. |
| [`docs/05-mascot-brief.md`](docs/05-mascot-brief.md) | The turtle. Last thing to build. |
| `assets/body-diagrams/` | 4 traced SVGs, muscle taxonomy, and the diagrams as Dart point data. |
| `assets/exercises/` | 260 exercises with setup / posture / execution / common mistakes. |
| `prototypes/` | Browser prototypes. Open them; nothing to install. |
| `lib/` | Flutter app. Theme, the generated data as Dart, and a placeholder screen. |
| `tool/sync_generated.sh` | Copies generated Dart from `assets/` into `lib/`; `--check` fails on drift. |

## The shape of it

Three tabs — **Workout**, **Muscles**, **History**. Profile sits behind an avatar in the header (`docs/adr/0003-l0-navigation-variant-a.md`).

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

All three run in CI (`.github/workflows/ci.yml`), which then fails on any diff.

## Getting started

```bash
flutter pub get
flutter run                                  # iOS simulator or Android emulator
flutter test
flutter analyze
```

Builds:

```bash
flutter build apk --debug                    # Android
flutter build ios --simulator --no-codesign  # iOS, no signing needed
```

Riverpod for state, Drift (SQLite) for storage — decided in session 1, see `CLAUDE.md`.
Bundle id is `dev.indresh.turtle_lift` (Android) / `dev.indresh.turtleLift` (iOS).
It is permanent from the first store upload, including internal test tracks.

iOS needs the iOS platform support installed in Xcode (Settings > Components, or
`xcodebuild -downloadPlatform iOS`). CocoaPods is **not** required — there is no
Podfile, and Xcode integrates Flutter's plugins through a local Swift package
(`Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`).

Note on the SQLite native library: `sqlite3_flutter_libs` resolves to `0.7.0+eol`,
a stub that ships **no native code** ("Not used anymore, update to version 3.x of
package:sqlite3 instead"). The real native library comes from `sqlite3` 3.6.0 via a
Dart **build hook** (`hook/`), not a platform plugin folder. That is why no plugin
needs a `Package.swift` — but it also means Drift's storage path depends on build
hooks working, which is worth confirming on a real device before relying on it.

```bash
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
