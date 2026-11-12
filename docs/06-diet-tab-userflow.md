# Diet — user flow

> **Accepted; placement superseded by `docs/adr/0007-diet-in-profile.md`:** Diet
> is the third Profile segment (Personal | Schedule | Diet), **not a fifth tab**.
> Where this flow says "tab", "L0" or "tab root", read Profile → Diet. ADR 0007
> also extends ADR 0005's notification exception to meal reminders, and the plan
> (`docs/plans/2026-11-08-1702-feat-diet-weekly-protein-plan.md`) settles the
> open questions below. Requirements: `.claude/prds/diet-plan.prd.md`. Visual
> reference: `prototypes/diet.html`.
>
> *Superseded draft wording, kept for history:* it needed an ADR that (a) adds a
> fifth tab, amending ADR 0003/0004, and (b) extends ADR 0005's notification
> exception to meal reminders.

**Purpose:** plan a week of high-protein meals once, see each day's protein
against a target, and get a reminder at each meal saying what to eat and how
much protein it gives.

**Entry point:** ~~the **Diet** tab in the L0 bar~~ (superseded, ADR 0007) —
the **Diet** segment of the Profile tab: Personal · Schedule · **Diet**. The L0
bar stays Workout · Muscles · History · Profile.

---

## Rules

- **One weekly plan.** Each weekday (Mon–Sun) has four slots: **Breakfast ·
  Lunch · Snack · Dinner**. Each slot holds zero or more foods, each with a
  serving count. The plan repeats every week.
- **The plan is a dated series, the same shape as Schedule (ADR 0005).** An
  edit takes effect from the Monday of the current week. Earlier weeks keep the
  plan that was in force then. This only matters because of the ticks below.
- **Marking a meal as eaten is optional, one tap per slot, for a calendar date**
  (`performedOn`-style local date, never a timestamp). Only today and earlier
  days of the current week can be ticked. A future day has no tick.
- **Nothing derived is stored.** Planned protein for a day, eaten protein, and
  "g to go" are computed on read from the plan, the catalogue and the ticks.
- **Protein target** is one number in g/day. The user can type it, or accept a
  suggestion computed from the bodyweight in effect today (Profile → Personal).
  With no bodyweight, there is no suggestion, only manual entry. With no target,
  the day shows the planned total with no bar.
- **Catalogue is read-only, bundled and offline.** It is Indian-first, in
  household units (katori, piece, glass, scoop) with grams shown. Every food has
  `dietType ∈ {veg, egg, nonVeg}`, a serving label, grams per serving, protein
  per serving, and a cited source. It is generated and validated like
  `exercises.json`, and never hand-edited.
- **Diet filter:** chips **All · Veg · Egg · Non-veg**, single select. Each chip
  shows only that type. (Open: should "Egg" mean veg + egg, the Indian
  "eggetarian" meaning? See PRD.)
- **Diet-type marker:** the palette has no green or red, so the usual Indian
  veg/non-veg dot can't be used. The type is shown as a text label and an
  outline glyph, in palette colours only.
- **Neutral copy, as in Schedule.** Counts, never verdicts: "86 of 120 g
  planned · 34 g to go". Never "behind", "failed" or "missed".

---

## Screens

### D1 · Diet landing (L0, tab root)

Top to bottom:

1. **Week strip.** Mon–Sun of the current week, with today selected. Each day
   shows a small fill showing planned ÷ target. Tapping a day switches the view
   below.
2. **Day card.**
   - Today or a past day: **Eaten X g · Planned Y g · Target Z g**, with a two-layer bar
     (eaten inside planned).
   - Future day: **Planned Y g of Z g**.
   - No target: "Planned Y g · Set a daily target", which links to D3.
3. **Four slot cards** (Breakfast 08:00, Lunch 13:00, Snack 17:00, Dinner
   20:30).
   - Each card lists its foods as name, servings and protein (e.g. "Paneer
     bhurji · 1 katori · 18 g"), with the slot's protein total on the right.
   - **+ Add food** opens D2 for this day and slot.
   - Tap a food to change servings or remove it (a sheet).
   - **Eaten tick** on the slot header, for today or a past day only.
   - An empty slot shows only "+ Add food".
4. **Header actions:** a bell icon opens D4 (reminders).

**Empty state (no plan at all):** "Plan your week's protein". One line explains
what the tab does, with a **Plan Monday** button that opens D2 for Monday ·
Breakfast.

### D2 · Add food (pushed)

- Title: "Add to Lunch · Wed".
- Search field, then the **diet chips** (All · Veg · Egg · Non-veg). The chip
  choice is remembered for the session, not stored.
- Rows show name, serving label (+ grams) and **protein per serving** on the
  right, sorted by protein per serving, highest first.
- Tapping a row opens the **add sheet**:
  - Servings stepper (½ steps, 0.5 to 4), with live protein ("2 katori ·
    24 g").
  - **Repeat on:** weekday chips, with the current day preselected. This is how
    the whole week gets filled quickly.
  - **Add** returns to D1 with the slot updated.

### D3 · Daily protein target (pushed)

- One numeric field, in g/day (an unsigned positive number, like every input).
- **Suggested** line, only when a bodyweight exists: "Suggested 115 g — 1.6 g ×
  72 kg (current bodyweight)". Tapping it fills the field. The multiplier and
  its source are open (PRD).
- Short note: "A guide, not medical advice. Talk to a doctor if you have a
  health condition."

### D4 · Meal reminders (pushed)

Follows ADR 0005 exactly, extended to meals:

- **Remind me** master switch. Turning it on for the first time shows an
  explain-first sheet, then the system permission. If permission is denied,
  everything else still works.
- **Morning summary**: on/off and a time (default 07:30).
- **One row per slot**: on/off and a time. The time is shared by all days; the
  defaults are listed under D1. Snack is off by default.
- Notifications are scheduled from the plan only:
  - a slot with no food that day sends no reminder;
  - a day with no food sends no summary.
  - They are **never** changed by ticks, so a meal already ticked still gets
    its reminder. There are no "you skipped lunch" messages.

---

## Notifications

| Kind | When | Title | Body | Tap |
|---|---|---|---|---|
| Morning summary | Summary time, on days with ≥1 planned food | `Today · 112 g protein planned` | `Breakfast: Paneer bhurji, Milk · Lunch: Rajma, Curd · Snack: Roasted chana · Dinner: Chicken curry` | Opens D1 on today |
| Meal | Slot time, if the slot has food that day | `Lunch · 28 g protein` | `Rajma, 1 katori (9 g) · Curd, 1 katori (11 g) · Roti × 2 (8 g)` | Opens D1 on today |

The copy is a fixed template filled from the plan. It never mentions what was
or wasn't eaten. (Open: should a **Mark eaten** action appear on the meal
notification?)

---

## Flow

```
L0 Diet ──▶ D1 Today (week strip · day card · 4 slots)
              │
              ├─ + Add food ──▶ D2 Food list (chips All/Veg/Egg/Non-veg)
              │                    └─ tap food ──▶ add sheet (servings · repeat on) ──▶ back to D1
              ├─ tap food ──▶ edit sheet (servings · remove)
              ├─ tick slot ──▶ eaten total updates in place
              ├─ day card (no target) ──▶ D3 Target
              └─ bell ──▶ D4 Reminders ──(first enable)──▶ explain sheet ──▶ OS permission

Morning summary notification ──▶ D1 today
Meal notification ──────────────▶ D1 today
```
