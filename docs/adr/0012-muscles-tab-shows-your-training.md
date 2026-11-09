# 12. The Muscles tab shows your training

Date: 2026-11-09

## Status

Accepted by the user (decisions on `docs/research/muscles-tab-audit.md`,
questions 1–6). **This lifts the deferral in `docs/00` §10 and `docs/03`**
("pure reference … nothing in it reads session history"). Amends `00` §5,
§10 and `03`.

## Context

The Muscles map was all grey whatever the user had logged. Every competitor
with a body map ties it to the user's training (audit §Competitors), and the
unslop audit named the body map as the app's "moment". The deferral was written
before sessions existed; they exist now, and the app already derives every
other figure on read.

## Decision

1. **The landing map shows this week's training, derived on read.** "This
   week" is Monday to Sunday, the same week as the Workout tab's week strip
   (`startOfWeek(planToday)`). A segment fills:
   - accent-strong (amber) when any of its muscles had a completed set this
     week from an exercise that trains it **directly** (primary);
   - accent-light (steel) when it was only worked as a **secondary** muscle;
   - muted otherwise.
   A small legend sits under the map; with nothing this week it says
   "Nothing trained this week yet. Muscles fill as you log sets."
2. **Per muscle: sets this week and last trained.** The muscle's exercise list
   and the shoulder sheet carry one line, e.g. "6 sets this week · Last trained
   today", "No sets this week · Last trained 9 days ago", "2 secondary sets
   this week", "Not trained yet". Screen readers hear the same line on each map
   segment. "Last trained" counts primary work only, up to today.
3. **Facts only.** No recovery %, readiness or "ready to train" model: those are
   modelled values the user cannot check against their log.
4. **Never stored.** `muscleTrainingProvider` (`lib/src/data/muscle_training.dart`)
   reads saved sessions plus the open one, so a completed set, an edit or a
   delete moves the map with no refresh path. Sets are counted with
   `isSetComplete`; a set never counts as both primary and secondary.
5. **Exercise detail shows a history line when the exercise has been logged**
   ("Last 62.5kg × 6 · 14 times · See history") into the existing Exercise
   history screen, which is no longer deferred. Nothing when never logged.
6. **Exercise detail offers "Start workout with this" when no workout is
   open**; with one open it keeps "Add to current workout", which turns into
   "In your workout" once added.
7. **Exercise lists get equipment filter chips** (outlined selection chips,
   derived from the list, held in memory only) and a derived "Last …" hint on
   rows that have history.
8. **The front shoulder keeps the label "Front delt"**; `00` §5 is corrected.

## Consequences

- `00` §10's "every segment renders muted" and "no history block" no longer
  hold for the landing and detail; the docs are updated to match.
- The exercise detail diagram is unchanged: it still shows the exercise's own
  primary/secondary muscles, not the user's training.
- Search still says nothing about the user (results are not ranked by history).
