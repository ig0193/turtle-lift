# 13. History is also the progress surface

Date: 2026-11-10

## Status

Accepted. The user approved every recommendation in
`docs/research/history-tab-audit.md` (open questions 1-8). **Amends `docs/00`
§11 and `docs/04`** (stats on History, one shared card, swipe delete, add an
exercise to a saved workout) and **settles the B17 conflicts** the audit
reported. Builds on ADR 0003 (derived lives on the tab), ADR 0008 (the current
week lives on the Workout landing) and ADR 0012 (the Muscles map shows your
training).

## Context

The audit found History answered "what did I do" but never "how am I doing":
no stats although `00` §11 specifies them, no per-exercise trend, exercise
history unreachable from History. It also found data-safety and consistency
bugs (B1-B17): a rename lost unless Return was pressed, no way to re-date a
saved workout, two hero cards that disagreed, no year on any short date, a
quadratic PB projection, and ghost workouts.

## Decision

1. **Stats on History.** One stats line at the top of the tab: day streak,
   total workouts, total sets, with the streak explainer (`docs/04` copy) one
   tap away. `00` §11 wins over the old "no stats block" comment. The calendar
   shows a total for **the month it displays** ("6 workouts · 82 sets").
   **Never the current week** on History: ADR 0008 keeps it on the Workout
   landing, and no figure appears in both places.
2. **Per-exercise progress chart** at the top of exercise history: the best set
   per session by load type (weighted: top weight with its reps; bodyweight:
   reps, or the added weight once any was added; assisted: the assistance with
   the axis **inverted**, less is better; timed: the longest hold). No e1RM or
   other modelled number. Under three sessions it says so instead of drawing.
   Range chips (3 months / 1 year / All) are held in memory only. Drawn with a
   `CustomPainter` in the closed palette (no chart package); a record session is
   the one amber dot; screen readers hear one sentence ("Best set rose from 60
   to 70 kg over 3 sessions").
3. **"Best at" table** on exercise history only: heaviest weight at 1-12 reps
   (weighted), lightest assist at 1-12 reps (assisted), most reps or longest
   hold at each added weight (bodyweight, timed). Quiet text, no amber, no
   alert. It does not change the PB rule.
4. **Dates.** One order everywhere: day, month, year. Lists omit the year in
   the current year and add it otherwise ("7 Nov", "7 Nov 2025"). The share
   card ("Tue 10 Nov 2026") and "first logged" always carry it. "Ago" switches
   to years from 12 months. One formatter: `lib/src/data/date_labels.dart`.
5. **Streak runs on the calendar.** A thin grey connector under every day
   between two workout days that chain by the streak rule (at most 3 days
   apart). The rule is written once (`streakChains` in `derived.dart`) and read
   by both the streak figure and the calendar.
6. **PB on list rows is quiet**: the word "PB" in muted grey, no count. The
   amber count stays on the card and the marked set in the log.
7. **Backfill and add an exercise, reusing existing flows.** An empty past day
   on the calendar offers "Log a workout for Tue 3 Nov?", which starts the
   ordinary ad-hoc workout dated that day (a workout already open is never
   replaced silently). A saved workout's editor has Add exercise (the same
   picker, then set logging on the saved session).
8. **One card, one derivation.** History detail and the editor render the same
   `SessionCard` (muscles at sub-muscle precision with secondaries in steel,
   "Day streak", PB takes the kcal slot, the same date). Records come from one
   chronological pass (`personalBestProjection`), cached in a provider, read by
   rows, the card, both logs and exercise history. The title chain is one
   function (`titleFromParts`), so a template workout is named after its
   template everywhere. The detail has Share in its header; exercise names in
   its log open exercise history, whose rows open the read-only detail.
9. **Editing is safe.** The title saves on Return, on losing focus and on
   leaving the screen. A saved workout has Change date (the same picker, today
   or earlier). Removing the only exercise with work offers to delete the
   workout; History never lists a workout with no completed set. History rows
   swipe left to delete behind the same confirmation, and offer Delete to
   VoiceOver as a custom action.

## Consequences

- No schema change. Everything above is derived on read or uses existing
  store calls (`createSession(performedOn:)`, `addExercise`, `setPerformedOn`).
- `CLAUDE.md`'s palette paragraph now describes the shipped Chalk & Shell
  palette (`00` §12), which it had not been updated for.
- Not built, per the audit's "later" list: a kg-volume chart (banned by `00`
  §3), e1RM or decaying strength, restore or soft delete, year-in-review,
  a weekly streak model, sharing history or charts, "start history from".
- The row glyph is still a separate small treatment beside `BodyDiagram`
  (audit B17); it is left as is and noted here rather than resolved.
