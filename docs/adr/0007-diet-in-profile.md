# 7. Diet is a protein-only weekly plan, in Profile

Date: 2026-11-08

## Status

Proposed — awaiting owner signature. **Amends the "not a nutrition app" line** in
`docs/01` §Not trying to be (and its V2 parking-lot entries), and the matching
lines in `docs/00` §13 and `CLAUDE.md` §Out of scope, for a protein-only weekly
plan and nothing wider. **Amends [ADR 0004](0004-profile-returns-as-a-tab.md)**:
Profile gains a third segment and its placement rule a second named exception.
**Extends [ADR 0005](0005-schedule-and-opt-in-notifications.md)**'s notification
exception to diet reminders, under the same rules. Supersedes the placement in
`docs/06-diet-tab-userflow.md` and `.claude/prds/diet-plan.prd.md`, which asked
for a fifth tab.

Plan: `docs/plans/2026-11-08-1702-feat-diet-weekly-protein-plan.md`. Visual
reference: `prototypes/diet.html` (re-skinned to the Profile segment).

## Context

People who train often under-eat protein, do not know which everyday foods carry
it, and drop diet apps because logging every meal takes too long. The PRD
(`.claude/prds/diet-plan.prd.md` §Evidence) collects the evidence: most urban
Indian respondents fall short of their protein requirement, vegetarians most of
all; over 90% do not know what they need; the top reason people quit a nutrition
app is the time logging takes. TurtleLift records the training and says nothing
about food, so users need a second app.

Four existing rules push against a diet feature:

- `docs/01` §Not trying to be: *not a nutrition app*, and the calorie line's *no
  logging food, no daily totals*.
- *No notifications* (amended once already, by ADR 0005, for Schedule only).
- *Derived lives on History; authored lives on Profile* (ADR 0004).
- *Four tabs is the ceiling; a fifth needs a new ADR* (ADR 0004).

The draft flow and PRD put Diet in a fifth tab. This ADR keeps the four-tab
ceiling instead.

## Decision

**1. Diet is in V1, narrowed to a protein-only weekly plan.** One plan, Monday to
Sunday, four slots a day (Breakfast, Lunch, Snack, Dinner). Each slot holds foods
from a bundled, reviewed food list, with a serving count. Each day shows planned
protein against an optional daily target. Protein is the only nutrient. No
calories, carbs, fat or macros; no free-form food logging, custom foods, online
food databases, barcode, photos or recipes; no AI meal plans; no diet streaks or
badges. The app stays *not a calorie or macro tracker and not a food diary*.

**2. Diet is the third Profile segment: Personal | Schedule | Diet.** Not a fifth
tab. The segment is held in memory (`profileSegmentProvider`), never stored:
Profile opens on Personal on every cold start and after Delete all data, and the
chosen segment survives tab switches within a run. A diet reminder tap is the one
outside entry that selects Diet.

**3. The plan is a dated series of whole weeks, keyed by Monday.** The same shape
and the same Monday rule as the Schedule plan (ADR 0005 §2): an edit takes effect
from the Monday of the current week, and earlier weeks keep the plan they were
lived under.

**4. An optional "eaten" tick per slot, for a local calendar date.** Only today
and earlier days of the current week can be ticked; a future day has no tick.
Eaten protein is the planned protein of the ticked slots, computed on read. A tick
never changes, suppresses or adds a reminder.

**5. Diet reminders follow ADR 0005's rules, unchanged.** Opt-in after an
explain-first sheet, local, fixed-schedule; a morning summary and one reminder per
meal slot, each with a time. Built from the plan only: an empty slot sends no
reminder, a day with nothing planned sends no summary, and the copy never mentions
what was or was not eaten. Neutral wording: counts, never verdicts.

## Why this does not reopen 0003

0003 rests on two riders: the bar shows only at L0, and an open session is the
Workout tab root. A Profile segment changes neither, and the bar's contents do
not change at all: still four tabs, Profile still index 3. A reminder tap pops to
the shell route before it selects Profile and Diet, so a tab switch is still only
reachable with an empty stack and the single root `Navigator` stays correct.

## Consequences

- **A second named exception to ADR 0004's placement rule.** Diet figures
  (planned, eaten, to go, the week meters) are derived yet live on Profile → Diet.
  They are the feedback loop for a plan the user has just typed, like the Schedule
  week summary. Condition: they never render on History, the summary card or the
  share card, and no workout figure renders on Diet. Reminder bodies are the one
  surface outside the app that carries gram figures.
- **ADR 0005's notification exception extends to diet reminders**, under the same
  five rules. Diet reminders ship only after the notification infrastructure
  exists; until then Diet shows no reminder control. Plugin constraint unchanged:
  it must ship a `Package.swift`.
- **Schema.** v6 adds `DietPlanVersions`, `DietPlanItems`, `MealTicks` and a
  nullable `Settings.proteinTargetG` (1 to 400). v7 adds `ReminderPrefs`, one row
  for the Schedule and diet reminder preferences. Both are numbered above the
  current version. Export gains a `diet` key (entered data only); Delete all data
  empties every diet table and cancels every scheduled notification.
- **Nothing derived is stored.** Planned, eaten, to go, meters, the suggestion and
  reminder text are all computed on read (`docs/01` §Derived values).
- **The food list is reviewed content.** `assets/foods/foods.json` is generated
  and validated like `exercises.json`, never hand-edited, and every food cites an
  IFCT 2017 food code (Longvah T et al., *Indian Food Composition Tables 2017*,
  NIN, ICMR). Foods IFCT 2017 does not cover are left out and listed for the
  owner's review. A food id, once shipped, is never removed or reused. Wrong
  numbers mislead users, so this copy needs the same care as the exercise
  content.
- **The protein rule.** The target suggestion is **1.6 g per kg of the bodyweight
  in effect today, rounded to the nearest 5 g** (halves round up), shown only when
  a bodyweight exists, and never stored: accepting it stores the number. It is
  framed as a common starting point, not an optimum, with a medical disclaimer.
  Sources:
  - Morton RW et al. 2018, "A systematic review, meta-analysis and
    meta-regression of the effect of protein supplementation on resistance
    training-induced gains in muscle mass and strength in healthy adults",
    *Br J Sports Med* 52:376-384, doi:10.1136/bjsports-2017-097608. Gains plateau
    beyond about 1.6 g/kg/day (breakpoint 1.62, 95% CI 1.03 to 2.20).
  - Jäger R et al. 2017, "International Society of Sports Nutrition Position
    Stand: protein and exercise", *JISSN* 14:20, doi:10.1186/s12970-017-0177-8.
    1.4 to 2.0 g/kg/day is sufficient for most exercising individuals.
- **Amended to match:** `docs/01` (§Not trying to be, §App structure, §V1
  technical scope, §V2 parking lot), `docs/00` (§1, §2, §3, §11, §13), ADR 0004,
  ADR 0005, `CLAUDE.md`, `docs/06-diet-tab-userflow.md` and the PRD.
- **Cost carried: discoverability.** A surface used a few times a day sits behind
  a tab and a segment. Accepted; reminders deep-link straight in, and the Workout
  tab gets no diet entry (ADR 0006 keeps it exercise-first). Promoting Diet to a
  tab later needs a new ADR, because it breaks ADR 0004's four-tab ceiling.
- **Deferred:** training/rest-day plans, a last-week view, a "Mark eaten"
  notification action, and the turtle mascot on Diet (last thing built, decided
  with the user).
