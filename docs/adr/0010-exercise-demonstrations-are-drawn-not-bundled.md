# 10. Exercise demonstrations are drawn, not bundled

Date: 2026-11-09

## Status

Accepted by the user's direct request. **This reverses a V1 out-of-scope item.**
`CLAUDE.md` and `docs/00` §13 listed "no per-exercise illustrations or
silhouettes" and "no exercise videos". The user asked for an exercise animation
on every detail page, like the openGym app. **Amends `docs/00` §13 and the
exercise detail layout.** Research: `docs/research/exercise-animations.md`.

## Context

openGym's detail-page animations are commercial stock from Gym Visual. Its
licence covers openGym only, so we cannot reuse them. The free alternatives
fail one way or another:

- ExerciseDB forbids storing its GIFs.
- free-exercise-db images have unknown provenance.
- Everkinetic (CC-BY-SA) and wger are 2-frame stills with partial coverage.
- LottieFiles has a handful of animations in mismatched styles.

This project has already had to replace a theme copied without a licence.

## Decision

1. **Every exercise has a demonstration, and the app draws it.** A pictogram
   figure is posed by keyframes (FK/IK limbs) and painted with
   `CustomPainter` in the closed palette (`lib/src/demo/`). There are no asset
   files, no third-party artwork, no new package, and nothing to attribute.
2. **Movement patterns, mapped per exercise.** `assets/exercises/animation_map.py`
   maps each of the 260 exercises to one of 155 patterns plus the gear in its
   hands. The validator writes both into `exercises.json` (`animation`,
   `animationGear`) and fails on:
   - a missing entry
   - an unknown pattern or gear
   - an unused pattern
   - an `other`-equipment exercise with no explicit gear

   `test/exercise_demo_test.dart` fails if any shipped pattern id has no Dart
   motion.
3. **Placement:** at the top of the exercise page, above Muscles. It is a
   surface card about 1.7:1 wide, clamped to 160–260pt tall.
4. **The primary muscles are painted amber on the figure.** This matches what
   the body map says, and amber keeps its one meaning.
5. **Motion rules:**
   - It plays three cycles, then rests on a two-position still (the start pose
     ghosted under the peak pose).
   - A 48pt play/pause button sits in the corner, with "Pause demonstration" /
     "Play demonstration" as its tooltip and label.
   - The figure carries the semantic label "Demonstration of {name}", plus
     ", paused" when stopped.
   - With Reduce Motion it shows the still and never starts on its own.
     Pressing play is an explicit request, so it plays.
   - Timed holds show a timer ring.
6. **The reviewed text stays the authority.** The figure is schematic, and the
   setup, posture, execution and common-mistakes copy is unchanged.

## Consequences

- App size grows by about 0.1 MB of Dart source and no assets. The bundled GIF
  or MP4 sets were tens of MB.
- The demonstrations are schematic, not photographic. Movements that rotate or
  sit outside the 2D plane are approximations: Pallof press, Russian twist,
  fire hydrant, flys (drawn from the foot of the bench).
- A user-created exercise (later) has no `animation`, so it shows no
  demonstration rather than a wrong one.
- Paid photographic stock (Gym Visual, WorkoutLabs) remains a possible V2 swap.
  The detail page reads one widget, so only `ExerciseDemo` would change.
