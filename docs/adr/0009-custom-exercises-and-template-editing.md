# 9. Custom exercises, templates built from scratch, and editing the live list

Date: 2026-11-09

## Status

Accepted (the user asked for it directly: "the user is not able to make a custom
template, add custom exercises to a template"). **Amends `docs/00` §2, §9, §11**,
`docs/02` (Custom templates, Step 3), `docs/04` (templates are authored on
Profile only) and ADR 0006 (templates were made only by Save as template).
Audit: `docs/research/workout-tab-functional-audit.md`.

## Decision

### 1. Custom exercises (schema step 8)

- A new table `custom_exercises`: `id`, `name`, `equipment`, `load_type`,
  `primary_ids`, `secondary_ids` (sub-muscle-group ids from the taxonomy,
  comma-joined). **Everything stored is what the user typed**; how often it was
  logged, its records and its last set are derived from the session tables like
  any library exercise.
- **Ids always start with `custom-`** (a `CHECK` in the table, and no shipped id
  carries the prefix; a test pins both). A custom id can never collide with a
  library id, and a later library regeneration cannot take one.
- **No reviewed content, ever.** The four content fields are empty strings. A
  custom exercise opens its own page (`CustomExerciseScreen`, reached through
  `pushExerciseDetail`), which shows the user's fields, the muscles on the body,
  and says plainly that there is no form guide. The app never writes, borrows or
  generates setup/posture/execution/mistakes text for one.
- **One index.** `libraryIndexProvider` is the boot-time shipped library;
  `exerciseIndexProvider` is library + custom. Every id lookup (picker,
  templates, session, set logging, history, records, title, export, Muscles tab
  search and lists) reads the merged one, so a custom exercise needs no special
  case anywhere. Custom exercises do appear on the Muscles tab under their muscle:
  they are the user's own catalogue, not training history.
- **The first-time Exercise Detail gate is skipped** for a custom exercise:
  the gate exists to show reviewed form cues, and there are none.
- **A logged custom exercise cannot be deleted** (its history would lose its
  name) **and its load type is fixed** (its sets and records would be
  reinterpreted). Name, equipment and muscles stay editable. An unlogged one can
  be deleted, which also removes it from every custom template in the same
  transaction.
- Export gains an `exercises` array (id, name, equipment, load type, muscles).
  Delete all data wipes the table.

### 2. Templates from scratch, and editing them

- `New template` on the Workout landing (a tile at the end of the My templates
  rail, which is now always shown) and on the template library. The editor:
  name, **Add exercises** (the picker in multi-select mode, with Create exercise),
  per-row move up / move down / remove, Save, and Delete on an existing one.
  Nothing is written until Save; leaving with changes asks first.
- **Arrows, not drag**, in the editor and the live list: two 44pt buttons work
  one-handed and are VoiceOver buttons; a drag handle is neither without custom
  actions.
- A custom template's row in the library and its preview sheet open the editor.
  Predefined templates stay immutable (Duplicate makes an editable copy).
- Editing a template never changes a workout already started from it (the
  session copies the list at start, unchanged rule).
- The library lists the user's own first, then Ready-made, then My exercises.

### 3. The live list

- `Edit list` on the session screen switches rows to move up / move down /
  remove. Order is stored as each row's position (it already was); nothing is
  derived from it except Up next.
- `addExercise` now appends at one past the highest position, not at the row
  count, which collided after a removal.

## Consequences

- Schema version 8. No existing row is read or rewritten by the step.
- `docs/00` §11's "building one from scratch ... is deferred" and "only place
  templates are authored" no longer hold: templates are authored on the Workout
  tab and the library (reached from Workout and Profile).
- **Left for the user:** notes, kg/lb, warm-up sets, supersets, swap in place
  (audit items 10–14).
