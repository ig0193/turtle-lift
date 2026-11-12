# 11. The combined build: swap, notes, hide from picker, and what stays deferred

Date: 2026-11-09

## Status

Accepted. Builds on ADR 0009 (custom exercises and template editing) and ADR
0010 (exercise demonstrations are drawn, not bundled). The user delegated
these calls ("take the best decision for the app and build").

## Context

Two pieces of work landed together on b2543d1: the Workout tab gaps (ADR 0009,
schema 8) and the exercise demonstrations (ADR 0010; it was numbered 0009 on its
own branch and renumbered when the two were combined). ADR 0009 left five audit
items for the user: notes, kg/lb, warm-up sets, supersets, swap in place. It
also left some behaviour that needed a yes or no.

## Decisions

### Kept as built

- **Demonstrations stay drawn.** The app-drawn figures are licence-clean,
  offline and a few kilobytes; they play three cycles and then rest, and the
  working muscles are amber, the same "worked" meaning as the body map. The
  weak spots ADR 0010's research note lists (machine levers that read as
  cables, a cramped deadlift bottom, the overhead-press head hiding the elbow)
  are left as next steps: each is a per-pattern tuning pass, not a quick fix.
- **A custom exercise has no demonstration and no placeholder.** It opens its
  own page (`CustomExerciseScreen`), which has no demo card at all.
- **Custom exercises appear on the Muscles tab** under their muscles. They are
  the user's training; leaving them out would make the map lie.
- **"My templates" is always shown**, ending in the New template tile, so a new
  user sees how to make one. `docs/02` §Landing is updated to match.
- **The plan stays read-only before Start logging.** The ready view is a
  glance; editing begins once logging does.

### Built

1. **Hide from picker.** A logged custom exercise still cannot be deleted —
   History must never show "Unknown exercise" — so the editor offers *Hide from
   picker* (and *Show in picker*) instead. Stored as `custom_exercises.hidden`.
   A hidden exercise is left out of the exercise picker only; it stays in
   History, records, the Muscles tab, My exercises (tagged "Hidden from
   picker") and export (`hiddenFromPicker: true`). If it is already in the
   open workout or the template being edited, the picker still lists it there.
2. **Swap in place.** In the live session's Edit list and in the template
   editor, a swap button replaces a row with an exercise from the picker, at
   the same position. **A live row with a completed set is never swapped**: a
   completed set is a record of that lift, and relabelling it would put its
   numbers in another exercise's history and records. The app says so in one
   line ("It has logged sets, so it stays. Add the other exercise instead.")
   and offers *Add instead*. A swap drops the old row's untouched half-typed
   sets, its note and its done tick, and snapshots the new exercise's load
   type. A replacement already in the workout is refused (one exercise is one
   row). A template has no sets, so its swap is never refused.
3. **Notes.** One optional free-text note per exercise per session
   (`session_exercises.note`, trimmed, at most 120 characters, `null` when
   blank). Typed in set logging (saved when the field lets go, not per
   keystroke), shown under the exercise in History detail, included in export,
   wiped by Delete all data with the rest of the session tables. Set logging
   also shows **"Last time: …"**, the most recent earlier saved session's note
   for that exercise — derived on read, never stored, so editing or deleting
   an old workout changes it with nothing to refresh.

### Schema step 9

`custom_exercises.hidden` (boolean, default false) and `session_exercises.note`
(nullable text), both `addColumn`; no existing row is read or rewritten. Each
column is added only where its table already exists without it, so an upgrade
from below 8 (which creates `custom_exercises` from today's definition) and a
development install that skipped the reserved session step both migrate.
`test/app_database_migration_test.dart` group `the hide-and-note step (8 -> 9)`
upgrades a transcribed version-8 database.

### Deferred, with reasons

- **kg / lb units.** Every number in the app is kilograms: the set formatter,
  stepper increments, PB comparison, the volume and calorie estimates, export.
  A unit setting touches all of them and needs a plan (convert at the edges,
  never store pounds) and its own tests, not a toggle.
- **Warm-up sets.** A warm-up flag changes what counts: the streak, set counts,
  the calorie estimate and which set is a record. Each of those rules would
  need a decision first.
- **Supersets.** Grouping exercises changes the session model (a group above
  SessionExercise), the live list, Up next and set logging's navigation. Too
  large to fold into this pass.

## Consequences

- Schema version 9. No later step may be numbered below it.
- `docs/00`, `docs/02` and `CLAUDE.md` describe swap, notes and hide.
- Maestro flows 15 (swap) and 16 (notes) cover the two new interactions.
