# 6. The Workout tab is exercise-first

Date: 2026-10-24

## Status

Accepted. **Supersedes** the muscle-first parts of `docs/02-workout-tab-userflow.md`
(Steps 1–3 and the `trained` tick), and overrides the matching lines in
`docs/00-build-spec.md` §2 and §9. Also overrides the "two overview paths are two
widgets" decision in `CLAUDE.md`, and the "no workout duration" rule **for the live
screen only** (see the clock, below).

Visual reference: `prototypes/workout-tab-options.html` (landing, session, logging)
and `prototypes/workout-start-moment.html` (the start moment, variant P2).

## Context

The Workout tab mixed two ideas. Predefined templates were *muscle menus*: you started
one, expanded a parent muscle group, tapped a sub-muscle group, chose an exercise, and
logged it. Ad-hoc sessions were *exercise lists*. The cost of the first showed up on
every exercise of every session — roughly three navigation taps before the first set —
and the app remembered none of it, so a regular lifter repeated the same drilling every
week. It also needed a set of rules that existed only to keep the muscle model coherent:
the template lock, the primary-only `trained` tick, and "the map and the list disagree
on purpose".

Starting a workout also did not *feel* like starting one: a list simply replaced another
list.

## Decision

**A session is a list of exercises.** A template is a pre-filled list; an ad-hoc session
is an empty one. Muscles describe the list, and are never how you move through it. The
Muscles tab is where you discover which exercise trains what.

- **Templates carry exercises, not muscle groups.** `WorkoutTemplate` stores an ordered
  list of exercise ids. The muscle line on a row ("Chest, shoulders, triceps") is derived
  from those exercises' primary muscles. The eleven predefined templates ship with
  curated lists of popular lifts.
- **Starting a template copies its list into the session.** Edits during the session
  never write back to the template.
- **One overview, not two.** One session screen serves both paths. The nested muscle
  list, the `trained` tick, the template lock and the "map and list disagree" rule are
  removed. The live body map stays: primary muscles fill strong, secondary muscles fill
  light, and a template session outlines its planned muscles until they are worked.
- **The split filter is dropped.** The landing is one view: a search bar (templates and
  exercises, by name), "My templates" above the predefined ones (absent when there are
  none), and a slim pinned **Start workout** bar ("Add exercises as you go"). With no
  filter there is no stored filter preference and no template-to-split membership.
- **Custom templates are made by "Save as template" after a workout.** Rename, duplicate
  and delete stay on the Profile tab, which remains the place templates are managed.
- **The start moment (P2).** Start opens the live session screen with one **Start
  logging** button; the exercise list is a half-height sheet over the map. Picking an
  exercise opens its logging screen directly. The "Workout in progress" pill appears only
  once logging has started.
- **Add to current workout works in any session**, not only ad-hoc ones, because a
  template no longer locks the session to its muscles.

### The clock: display-only duration

A live elapsed clock shows beside the "Workout in progress" pill and under the exercise
name while logging. It is **never stored and never shown anywhere else** — not in History,
not on the summary card, not on the share card. That keeps the reason `docs/01` gave for
"no workout duration" intact: retrospective logging makes a stored duration meaningless.

- It counts from when the workout started (`loggedAt`), which is within seconds of the
  Start logging tap.
- It shows only when the session is dated the day it was started and has been running for
  under six hours. A backdated session therefore never shows a clock, and a session left
  open for days never shows a huge or meaningless one.

## Consequences

- **Schema 5.** `CustomTemplates` gains an `exerciseIds` column. The old `groupIds`
  column stays in place (it cannot be dropped without rebuilding the table) and is no
  longer written. The migration copies a duplicate's exercise list from the predefined
  template it came from; a template with no known source ends up empty. `Sessions.groupIds`
  is likewise no longer written or read.
- **The first-time detour stays.** An exercise the user has never completed opens its
  reference page first, with a "Start logging" action. On a fresh install every template
  exercise is new, so the first session takes an extra tap per exercise; that is the
  existing rule working as designed.
- **Removed:** `TemplateFilter` and its control, `TemplateOverviewBody`, the nested muscle
  list, `trainedSubGroups` as a session list, the template lock, and the pinned
  muscle-exercise list reached from a session.
- **Still open:** reordering and swapping an exercise on a session row; an "Add weight"
  chip for bodyweight and timed exercises; quick-fill duration chips.
- **Out of scope remains out of scope:** no rest timer, no stored duration, no suggestion
  of which workout to do.
