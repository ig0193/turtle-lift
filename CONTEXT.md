# TurtleLift

An offline workout log. One person, one device, no account. The model is
deliberately thin: almost nothing the user sees is stored, because sessions stay
editable and any stored aggregate goes stale the moment one is changed.

## Language

### What the user builds and runs

**Routine**:
An ordered list of exercises with target sets, saved by the user and started to
create a session. Introduced by `adr/0004`.
_Avoid_: Program, plan, workout (a routine is never a session)

**Template**:
One of the 11 shipped sets of **parent muscle groups**, carrying no exercises. A
starting point that pre-filters the exercise picker, not something you run.
_Avoid_: Routine, preset, split (the *split* is the filter a template is listed under)

**Folder**:
A named group of routines on the Workout landing. Holds routines only; never
nests.

**Session**:
One workout that happened, on one calendar date. Open (in progress) or saved;
exactly one can be open at a time.
_Avoid_: Workout log, entry, activity

**Set**:
One numbered row under an exercise in a session. It is *completed* only when its
checkmark is ticked **and** its required field is above zero — that pairing is
the definition every derived figure counts on.
_Avoid_: Rep, entry

### How an exercise is measured

**Load type**:
Which numbers an exercise takes — `weighted`, `bodyweight`, `assisted` or
`timed`. It is snapshotted onto the session row when the exercise is added, so a
later library change cannot rewrite history.
_Avoid_: Exercise type, category, measurement

**Assist**:
The weight *taken off* on an assisted exercise. Its own field on its own load
type, always a positive number — the app has no minus sign anywhere.
_Avoid_: Negative weight, offset

**Personal best**:
The best single set ever recorded for an exercise, strictly greater than every
prior one. On assisted exercises **less assistance is better**, which makes it
the one place a smaller number wins.
_Avoid_: PR, record (in prose; `PB` is fine in UI copy)

### What the body map says

**Parent muscle group** / **Sub-muscle group**:
The two levels of the taxonomy — 12 parents, 19 sub-groups. Templates name
parents only; the body map fills sub-groups.
_Avoid_: Muscle, region, zone

**Segment**:
One drawable, tappable shape on a body diagram. 42 of them across the four
diagrams. A segment maps to a sub-muscle group; it is not itself a muscle.
_Avoid_: Path, area

**Trained**:
A sub-muscle group has been trained when an exercise listing it as a **primary**
muscle has a completed set this session. Derived, binary, and it gates nothing.
_Avoid_: Done, complete, worked (**worked** is the map's wider primary-and-secondary
reading, and the two are meant to disagree)

### Time

**`performedOn`**:
The local calendar date a session is filed under. Not a timestamp — an 11pm
session must not land on the next day. The user can change it; it can never be in
the future.
_Avoid_: Date, timestamp, when

**`loggedAt`** / **`startedAt`** / **`endedAt`**:
Internal timestamps — ordering tiebreaker, and the two ends the live duration is
derived from. None of them is ever shown as a date.

**Streak**:
Consecutive trained days allowing a gap of up to three, measured against *today*
rather than stored. A backdated session slots into the chain rather than starting
a new one.
_Avoid_: Consistency score, chain
