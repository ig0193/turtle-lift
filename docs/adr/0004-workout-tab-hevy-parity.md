# 4. The Workout tab is rebuilt to Hevy's shape

Date: 2026-09-23

## Status

Accepted. Amends `docs/00-build-spec.md` §3, §9, §13 and `docs/02-workout-tab-userflow.md`
Steps 1, 4, 5 and 6. Supersedes the template-lock and Mark-exercise-done rules outright.

## Context

The Workout tab shipped as this app's own design: a landing of **templates** —
named sets of *parent muscle groups*, carrying no exercises — and a live session
that ran across three screens. An overview (nested muscle list on the template
path, flat exercise list on the ad-hoc path) listed what there was to do; tapping
an entry **pushed** a `SetLoggingScreen` for that one exercise; finishing it
returned to the overview. Every exercise cost a push and a pop.

The user asked for the Workout tab to match the Hevy app — functionality, UI and
UX — and supplied 27 screenshots of it. Hevy's tab is a different shape in two
ways that are not stylistic:

- Its landing lists **routines**: ordered exercise lists with target sets, kept
  in folders. Not muscle groups.
- Its live session is **one scrolling screen**. Every exercise and every set is
  inline, in a `SET · PREVIOUS · KG · REPS · ✓` table. Nothing is pushed.

Copying it collided with rules this repo had deliberately written down. Four were
put to the user, who chose: keep TurtleLift's palette and render Hevy's layout in
it; **build** the session duration and the rest timer that §13 banned; take
routine folders and per-exercise notes but not set types, supersets, RPE or a
plate calculator; and keep the two overview screens rather than delete them.

## Decision

**The tab is rebuilt around Hevy's flow.** A live session runs on one
`LogWorkoutScreen` with every exercise and set inline. The landing lists routines
in folders. Six rules are reversed to make that coherent:

1. **Rest timer and workout duration are built** (`00` §13). The duration is
   derived from two new stored timestamps, `startedAt` and `endedAt`; it is not a
   stored counter. The rest timer is foreground-only and raises no notification,
   so the notification ban is untouched.
2. **Lifted volume exists, derived on read** (`00` §3) — Σ (weight × reps) over
   completed sets. It renders in the Log Workout summary bar only, never on the
   screenshot-shaped summary card, and set count stays the headline stat.
3. **The template lock is dropped** (`00` §9). It had nothing left to enforce: a
   routine is an ordered exercise list, not a claim over muscle groups.
4. **Mark exercise done is removed** (`00` §9, `02` Step 4). Hevy has no
   equivalent, and the button's only other job — ticking a muscle without a
   logged set — was already redundant.
5. **The set-logging screen's fixed order now governs history editing only**
   (`02` Step 4). Live logging is the inline block, which has no Recent section.
6. **Templates become starting points, not a session type.** The 11 predefined
   muscle-group templates survive behind a **Templates** button; picking one opens
   an empty workout with the exercise picker pre-filtered to its groups.

### Considered and rejected

- **Keep the push-per-exercise flow and restyle it.** Cheapest, and it would have
  preserved every rule above. Rejected because the push *is* the thing being
  replaced: Hevy's speed comes from never leaving the list, and a restyled push
  flow would have matched the screenshots on colour while missing the point.
- **Give the 11 predefined templates default exercise lists**, making them real
  routines. Rejected as a content decision disguised as a schema decision —
  `exercises.json` is reviewed copy, and inventing eleven prescribed workouts is
  exactly the "today's workout" suggestion `02` refuses to make.
- **Delete the two overview screens.** Hevy has no equivalent, so they are now
  unreachable from the main path. The user chose to keep them and decide later;
  they hang off the body figures in the summary bar.

## Amended: no routine folders

Folders were built, then removed at the user's request after the create-folder
dialog crashed on device. The crash was a disposed text controller and is fixed;
the removal is a separate, deliberate call — the landing is a flat list of
routines under **My routines**, and Hevy's folders are a divergence this app
accepts. Routines still reorder by long-press drag.

`RoutineFolders` and `Routines.folderId` remain defined and inert. Dropping them
means rebuilding `Routines` to shed a foreign key, and a table rebuild is the
riskiest migration there is; running one to delete an empty table would spend
that risk on tidiness. They go out with the next migration that has a real
reason to rebuild the table.

## Consequences

**`markedDone` outlives its UI.** The column stays on `SessionExercises` for
schema stability and for editing saved sessions, but nothing in a live workout
writes it. `countsAsTrained` therefore reduces in practice to *has a completed
set*. This is half of a session-1 decision ("a muscle ticks on a completed set as
well as on Mark exercise done") and the surviving half is the one that mattered.

**Two set-entry surfaces exist.** `SetLoggingScreen` survives for editing a saved
session from History, while live logging happens inline. They must keep rendering
sets through the one shared formatter — the rule `test/history_session_detail_test.dart`
already locks. Unifying them is a follow-up, deliberately not in this change.

**Volume is a partial figure and always will be.** It cannot include bodyweight
or timed exercises. That was the original reason for banning it, and the reason
has not gone away — it is now shown anyway, small, beside two figures that are
complete. If it ever becomes the headline stat, the ban was right and this was
wrong.

**The set-logging screen is no longer the app's most-used screen.** The build
order in `CLAUDE.md` put it second because it exercised every hard decision at
once — four load types, prefills, PB computation, completed-set rules. All of
that moved to the inline block, which is where that reasoning now applies.
