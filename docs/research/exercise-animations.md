# Exercise demonstration animations: research and decision

Date: 2026-11-09. Requested: "openGym has the exercise animation on the details
page. We also want great animations for each exercise. Add them in TurtleLift."

## What openGym does

The app is **DuarteSantos8/openGym**, a self-hosted, AGPL-3.0 workout tracker.
It ships on the iOS App Store with a Watch app, on Android, and as a web PWA.
<https://github.com/DuarteSantos8/openGym>

- About 5,600 exercises. Each has an animated demo (a 360 px loop in the app,
  180 px on the web) and a still image. Source: v1.4.0 release notes,
  <https://newreleases.io/project/github/DuarteSantos8/openGym/release/v1.4.0>.
- **The animations are commercial stock from Gym Visual.** The repo's media
  notice says the stills and animations are "© Aliaksandr Makatserchyk, Gym
  visual … licensed for use in openGym only", and that the AGPL does not cover
  them. Any other use needs a licence bought from <https://gymvisual.com>.
- The gitea and sourceforge "openGym" repos are forks or mirrors of the same
  project.

**We cannot reuse openGym's assets.** Copying them is exactly the theme mistake
this project already had to undo.

## Options

| Source | Licence | Format | Coverage of our 260 | Verdict |
|---|---|---|---|---|
| openGym / Gym Visual | Proprietary, openGym only (paid licence otherwise) | GIF/MP4 loops | High | **Rejected**: no licence for us |
| ExerciseDB / AscendAPI (exercisedb.dev) | Proprietary. The subscription licence is revocable and storage is forbidden (<https://exercisedb.notion.site/ExerciseDB-API-Terms-of-Use-226983b728ca8090bf7be79564e4b356>). The GIFs trace back to Gym Visual | GIF | High | **Rejected**: cannot be bundled offline |
| yuhonas/free-exercise-db | The repo is Unlicense, but the maintainer says the image source is unknown (<https://github.com/yuhonas/free-exercise-db/issues/2>) | 2 JPG photos per exercise | Medium | **Rejected**: image provenance unknown |
| Everkinetic (<https://github.com/everkinetic/data>) | CC-BY-SA 4.0 (an older mirror says 3.0). The `images-ai` folder has unclear provenance | 2 line-art frames (start and end), not an animation | About 290 entries, partial overlap | Possible. Requires attribution and share-alike on any edited image, and is a 2-frame crossfade at best |
| wger.de (<https://wger.de/api/v2/exerciseimage/>) | Set per image: CC-BY-SA 3/4, CC0, CC-BY 4 (<https://wger.de/api/v2/license/>) | Mostly stills. Videos are 1080p HEVC at about 34 MB per 10 s | Thin and mixed styles | Rejected: too inconsistent, and the videos are far too large |
| LottieFiles free animations | Lottie Simple License: commercial use allowed, no attribution (<https://lottiefiles.com/page/license>) | Lottie JSON | A handful (squat, push-up…), each by a different artist | Rejected as the main source: about 10 of 260, and the styles don't match |
| Paid stock (Gym Visual, WorkoutLabs from about $1,200/yr) | Commercial licence | GIF/MP4/PNG | High | Possible, but costs money and adds tens of MB. **User decision** |
| **Original parametric animation drawn in Flutter** | Our own work, no third-party licence | Dart code (CustomPainter), no asset files | **260 of 260** | **Chosen** |

On CC-BY-SA inside a closed-source app: share-alike applies to adaptations of
the image, not to the app that displays it. A recoloured image would still have
to be published under CC-BY-SA. The chosen approach avoids the question
entirely.

## Decision

Draw every demonstration in the app. A figure made of capsule limbs (a
pictogram style) is posed by keyframes and animated with CustomPainter, in the
app's own palette:

- the body in chalk greys
- the exercise's **primary muscles painted amber on the figure**, the same
  statement the body map makes below it
- the equipment drawn into the hands: bar, dumbbell, kettlebell, cable with its
  pulley, band, machine lever, plate, landmine, ab wheel, ball, jump rope

Each exercise maps to one of 155 movement patterns plus a gear kind. The
mapping lives in `assets/exercises/animation_map.py`, and the validator writes
it into `exercises.json` as `animation` / `animationGear`.

Why this approach:

- **Licence-clean.** There are no third-party assets, so there is no
  attribution screen and nothing to add to `LicenseRegistry`.
- **Offline and tiny.** It adds about 0.1 MB of Dart source and zero asset
  files, against tens of MB for GIF or MP4 sets.
- **Consistent.** All 260 share one style and one palette. It respects Reduce
  Motion with a two-position still (the start pose ghosted under the peak
  pose), and has a play/pause control.
- **Honest scope.** These are schematic demonstrations, not photographic. Some
  movements are approximations, and the reviewed text copy remains the
  authority. Rotational and lateral moves (Pallof press, Russian twist, fire
  hydrant) are the weakest in 2D.

## Files

- `lib/src/demo/figure_rig.dart`: pose, FK/IK limbs, solver
- `lib/src/demo/exercise_motion.dart`: keyframes, props, gear rig
- `lib/src/demo/demo_painter.dart`: rendering
- `lib/src/demo/demo_catalogue.dart`: the 155 patterns
- `assets/exercises/animation_map.py`: exercise to pattern and gear (validated)
- `tool/demo_sheet_test.dart`: renders contact sheets of all 260 for review
  (`DEMO_SHEET_DIR=… flutter test tool/demo_sheet_test.dart`)

## Progress / next steps

- [x] Research and decision (this file)
- [x] Rig, painter, and a catalogue of 155 patterns. All 260 of 260
      exercises are mapped, and the validator is wired in
- [x] Detail-page widget: autoplays for 3 cycles, then rests on the still.
      It has play/pause, a Reduce Motion still and semantics
- [x] Tests in `test/exercise_demo_test.dart` (8): coverage, finite joints,
      play/pause, rest, Reduce Motion. Full suite: 1303 passing
- [x] ADR 0010 (renumbered from 0009 when combined with the custom-exercises ADR), CLAUDE.md and docs/00 amended
- [x] iPhone 17e screenshots and video (scratchpad)
- [ ] **Visual polish pass.** Only about 8 of 22 contact sheets have been
      reviewed by eye. Known weak spots:
      - machine chest press and leg press levers look like cables
      - the deadlift bottom position is cramped
      - the decline bench leg hook is odd
      - Pallof press, Russian twist and fire hydrant are 2D approximations
      - the side-view head hides the elbow at the overhead-press rack position
- [ ] Optionally a Pro Max check. The card height is clamped to 160–260pt by
      width, so a wider screen gets a taller card
