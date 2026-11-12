---
title: Diet tab - integration plan
type: feat
date: 2026-11-08
status: PROPOSED. Nothing here is accepted until the owner signs off ADR 0007 (§1).
inputs: docs/06-diet-tab-userflow.md, prototypes/diet.html, .claude/prds/diet-plan.prd.md (all DRAFT, untracked)
---

# Diet tab: integration plan

**What it is.** A weekly, protein-only meal plan from a bundled offline food list. It shows each
day's protein against a target, has an optional "eaten" tick per meal, and opt-in meal reminders.
It is **not** food logging, calorie tracking or macro tracking.

**Authority.** `CLAUDE.md` hard rules > `docs/01`–`04` > `docs/00` > this plan. `prototypes/`
win on layout only. Where this plan amends a doc, it says so and the amendment goes into ADR 0007.

---

## 0. What the three diet sources say, and where they disagree

### Agreed by all three
- A fifth L0 tab, **Diet**, in the order Workout · Muscles · History · **Diet** · Profile.
- One weekly plan, Mon–Sun × four slots (Breakfast · Lunch · Snack · Dinner). Each slot holds foods
  × servings, and the plan repeats every week.
- Protein only. A bundled, read-only, offline catalogue (Indian-first, household units, IFCT 2017,
  one source cited per food), generated and validated like `exercises.json`.
- Diet filter chips **All · Veg · Egg · Non-veg**, and a diet-type marker that uses shape, not colour.
- An optional "eaten" tick per slot, for a calendar date. Nothing derived is stored.
- A protein target in g/day, typed by the user or suggested from today's bodyweight.
- Opt-in local reminders under ADR 0005 rules: a morning summary plus one per slot, never reacting
  to behaviour.
- Out: calories, carbs, fat, custom foods, barcode, recipes, photos, AI plans, shopping, premium,
  clinical diets.

### Where they disagree or leave a gap

| # | Topic | Userflow (06) | Prototype (diet.html) | PRD | Resolution in this plan |
|---|---|---|---|---|---|
| D1 | Palette, type, labels | none stated | Old warm "Coral" palette (`#D85A30`), Inter fetched from Google Fonts, UPPERCASE tracked labels (`MON`, `REPEAT ON`), text at 9.5–11.5px, a flat bar instead of the glass bar | Milestone 3 says the diet screens get added to `screens.html` | Before any build, re-skin the prototype to ONE DAY (`00` §12) and the turtle-taste rules. Layout stays authoritative; its colours, font and type sizes do not (Q11) |
| D2 | Day card copy | "Eaten X g · Planned Y g · Target Z g" | "86 of 120 g planned · 34 g to go · X g eaten", plus "Target reached in the plan" | "running total against the target" | Use the prototype copy. It is neutral and has the bigger number first. Drop "Target reached in the plan" for "120 of 120 g planned" (counts, not verdicts) |
| D3 | Empty state | One button, "Plan Monday" | Adds a ghost "Set a daily target first" | — | Use the prototype: one filled button plus one ghost (taste rule: one filled per view) |
| D4 | Slot header time | Fixed times shown ("Breakfast 08:00") | The reminder time, or "No reminder" | — | Show no time until reminders ship (S7). After that, show the reminder time only when that slot's reminder is on |
| D5 | Adding a food already in the slot | not stated | Replaces the servings | — | Replace, on every "Repeat on" day. One row per (day, slot, food) |
| D6 | Why the plan is a dated series | "only matters because of the ticks" | Ticks keyed by weekday index, no dates | "Editing the plan never rewrites past weeks" | The week strip shows only the current week, so a past week's ticks show **nowhere**. Keep the series (export, a future history view), but see Q3 |
| D7 | Editing the plan mid-week vs ticks | Edits take effect from this Monday | Target helper says "it never rewrites what you ticked" | — | False as written. Eaten = plan × ticks, so editing Monday's lunch on Wednesday changes Monday's eaten total. Accept it (it is the user correcting Monday) and remove that helper sentence (Q4) |
| D8 | Egg chip | "each chip shows only that type" (open) | Exclusive | Open: egg-only, or veg + egg ("eggetarian") | Q5 |
| D9 | Copy punctuation | "Suggested 115 g — 1.6 g × 72 kg" | Em dashes in copy | — | Turtle-taste bans em and en dashes as separators. Use "Suggested 115 g. 1.6 g per kg at 72 kg, your current bodyweight." |
| D10 | Tick control | "Eaten tick on the slot header" | A filled accent square when on | — | Taste rule: selection controls are outlined. When on, show an accent outline and a check glyph, plus the word "Eaten" for screen readers. No fill |
| D11 | Timing of ADR 0005 notifications | "Follows ADR 0005 exactly" | Reminders shown working | Milestone 6 | ADR 0005 notifications **are not built yet**: the Schedule's Remind me row is inert and there is no plugin in `pubspec.yaml`. Diet reminders can only follow that ticket |
| D12 | Brief vs PRD | — | — | Plan-first, no custom foods, no calories | This plan's brief asked for stories on food logging with quantities, custom foods, macros and calorie estimates. The PRD rules all of these out and `docs/01` forbids them. Covered in §1 as cut, not planned |

---

## 1. Scope check (do this first; it blocks everything else)

**This is a V1 scope expansion that changes the product's stated identity.** `docs/01` §Not trying
to be (lines 27–28) says: *"A nutrition app. A calorie tracking app … no goals, no budgets, no
logging food, no daily totals."* `01` wins over `00` and over these drafts. Diet has a goal (target),
a daily total, and an "eaten" record that is food logging in all but name. **It cannot be built on
a reading of the current docs. It needs the owner's sign-off, recorded as ADR 0007.**

### ADR 0007 (proposed) must decide and amend

| Amends | Change |
|---|---|
| `docs/01` §Not trying to be | Narrow it to: "not a calorie or macro tracker, not a food diary". Allow a protein-only weekly plan |
| `docs/01` §App structure, `docs/00` §11 | Five tabs |
| ADR 0004 "Four tabs is the ceiling … a fifth needs a new ADR" | This is that ADR. Restate why 0003's invariant still holds (§3) |
| ADR 0005 notification exception | Extend it to meal reminders under the same five rules |
| `docs/00` §1, §2, §3, §13, `CLAUDE.md` Out of scope / Build order / Generated data | New shipped asset, tables, derived values, and the step in the build order |
| Placement rule (ADR 0004) | Add: "Diet figures live only on the Diet tab". None on History or Profile |

### Compatible / cut / decide

| Item | Verdict | Why |
|---|---|---|
| Bundled offline catalogue (JSON, generator + validator) | **Compatible** | Same pattern as `exercises.json`. No network |
| Weekly plan, servings, target, derived totals | **Compatible once ADR 0007 is signed** | Conflicts only with `01` §Not trying to be |
| Optional eaten tick per slot/date | **Decide** (Q1) | This is the part closest to "logging food". It can be cut without breaking the plan |
| Target suggestion from bodyweight | **Compatible** | Reads the existing dated bodyweight series. The multiplier needs a cited source (Q6) |
| Opt-in meal reminders | **Compatible, deferred** | Only after ADR 0005 notifications ship. The plugin must ship `Package.swift` |
| "Mark eaten" action on the notification | **Defer** | Needs a background isolate that writes the DB. Not V1 |
| Calories, carbs, fat, macros | **Cut** | `01` §Not trying to be, and the PRD's own out-of-scope list. The per-session calorie estimate is unrelated and stays |
| Calorie estimate for food | **Cut** | Same reason |
| Free-form food logging (what I ate, quantities, times) | **Cut** | PRD: logging effort is the main reason users quit. `01` forbids it |
| Custom (user-created) foods | **Cut for V1** (Q8) | PRD out of scope. They would also break "every value is cited and reviewed" |
| Online food database or API lookups | **Cut** | Offline, local-only |
| Barcode scanning, photos | **Cut** | Network/camera, PRD out of scope |
| AI meal suggestions, auto-generated plans | **Cut** | `CLAUDE.md`: no AI features |
| Streaks, "days on target" badges | **Cut** | No achievements. A diet streak would compete with the workout streak |
| Wearables, Health/Google Fit sync | **Cut** | `CLAUDE.md` out of scope |
| Premium, ads, cloud | **Cut** | `CLAUDE.md` |
| Different plans for training vs rest days | **Defer** (Q7) | The PRD leaves it open, and it doubles the plan model |
| Turtle mascot on Diet | **Defer** | Last thing built, decided with the user |

---

## 2. User stories with acceptance criteria

These follow the PRD's plan-first model. "Today" means `LocalDate.today()`. Every date is a local
calendar date, never a timestamp.

**US1. First open, no plan.** *As a lifter opening Diet for the first time, I see what it does and
one obvious way to start.*
- The `EmptyState` shows a new bowl glyph, "Plan your week's protein", one line of body copy, a
  filled **Plan Monday** button, and a ghost **Set a daily target**.
- Plan Monday opens D2 for Monday · Breakfast. Set a daily target opens D3.
- No onboarding wizard (`01` §App structure). Nothing asks for permission.

**US2. Set a target.** *As a user, I set my daily protein in g, or accept a suggestion based on my
bodyweight.*
- D3 has one numeric field: whole grams, an unsigned positive integer from 1 to 400 (Q6). It is
  stored as typed.
- If a bodyweight is in effect today (`weightInEffectProvider`), show one outlined suggestion row,
  "Suggested 115 g", with the working: "1.6 g per kg at 72 kg, your current bodyweight". Tapping
  it fills the field and does not save it.
- With no bodyweight, show no suggestion row. Show "Add your bodyweight in Profile to get a
  suggestion" as a link to `PersonalDetailsScreen`.
- The stored number does **not** follow later bodyweight changes. Accepting a suggestion stores
  the number, not a "follow bodyweight" flag.
- A fixed disclaimer: "A guide, not medical advice. If you have a health condition, talk to a
  doctor before changing your diet."
- A clear-target action (ghost) sets the target to null, and the day card goes back to the
  no-target copy.

**US3. Add a food to a slot.** *As a user, I pick a food for a meal in a few taps.*
- D2's title is "Add to Lunch, Wed". It has a search field and diet chips. Rows show name, serving
  label with grams, and protein per serving, sorted by protein per serving (highest first), then by
  name.
- Search matches the name and any aliases, ignoring case and diacritics. If nothing matches, the
  list reads "No foods match" plus a ghost "Clear search".
- The chip choice lasts while the app runs (in memory, like `loggingStartedProvider`) and is never
  stored.
- Tapping a row opens the add sheet: a servings stepper (0.5 to 4 in 0.5 steps) with live protein
  ("2 katori, 24 g"), **Repeat on** weekday chips (outlined, the current day preselected), and
  **Add to Lunch** (filled).
- Add writes one row per selected weekday in one transaction. If the food is already in that slot
  on that day, its servings are replaced (D5). The sheet closes, D2 pops, and D1 shows the slot
  updated.
- Repeat on with no day selected disables Add, and "Pick at least one day" is shown nearby.

**US4. Fill the whole week fast.** *As a user, I plan seven days in a few minutes.*
- Repeat on makes adding Mon–Fri one action.
- Every day in the week strip shows a small planned ÷ target meter (no meter without a target).
  Tapping a day switches D1.
- *Measure:* a seeded test plans 4 slots × 7 days in 12 or fewer sheet commits.

**US5. Change or remove a planned food.** *As a user, I fix a serving or drop a food.*
- Tapping a food on D1 opens the edit sheet: a stepper, **Save** (filled), and **Remove from
  Lunch** (ghost, `danger` text). It edits only that weekday.
- Remove takes no confirmation dialog because it is a one-row, easily redone change. It shows an
  undo snackbar for 4 s instead (Q9).
- Edits obey the dated-series rule (§4). The current week and future weeks change. A past week's
  plan never does.

**US6. View a day.** *As a user, I see today's planned protein against my target at a glance.*
- With a target, on today or a past day of this week: "86 of 120 g planned", sub-line "34 g to go"
  (omitted once planned ≥ target), plus "52 g eaten" if any slot is ticked. A two-layer bar shows
  planned in `textMuted` on `mutedSurface`, eaten in `accentStrong`, with a "Planned" / "Eaten"
  legend so status is never shown by colour alone.
- A future day shows "86 of 120 g planned" and the bar, with no eaten layer and no legend entry.
- With no target: "86 g planned" plus a "Set a daily target" link to D3. No bar.
- With 0 g planned and a target: "0 of 120 g planned", plus "Nothing planned for Thursday" above
  four slots that each show only "+ Add food".
- Copy never uses "behind", "failed", "missed", "over" or "great job".

**US7. Mark a meal eaten (optional, Q1).** *As a user, I tick a meal so the day shows what I
actually ate.*
- The tick shows only on a non-empty slot, on today or an earlier day of the current week. It is
  absent on future days and empty slots, never just disabled.
- One tap toggles it. On writes a row `(date, slot)`. Off deletes the row (hard delete).
- Eaten for a day is the sum of the planned protein of its ticked slots, under the plan in effect
  on that date. It is computed on read.
- If a ticked slot becomes empty, it counts 0 g and shows no tick. The row stays, harmlessly.
- Ticks never change reminders.

**US8. Reminders (after ADR 0005 notifications ship).** *As a user, I opt in to a morning summary
and per-meal notes.*
- D4 (bell in the D1 header): **Remind me** master switch. The first time it is turned on, the
  explain-first sheet appears (reuse the Schedule `_ExplainSheet` shape), then the OS prompt. If
  permission is denied, everything else still works, and a line says how to enable it in Settings.
- Morning summary: on/off plus a time (default 07:30). Per slot: on/off plus a time (defaults
  08:00 / 13:00 / 17:00 off / 20:30). Times are minutes after local midnight and apply to every day.
- Notifications are built only from the plan. A slot with no food that day sends nothing. A day
  with no food sends no summary. Ticks never suppress or add one. The copy is a fixed template
  (06 §Notifications) with no em dashes.
- Tapping a notification switches to the Diet tab, today. If a route is pushed, it pops to root
  first. The open session is the Workout root at depth zero, so popping loses nothing.
- After any plan edit, reminder change, time-zone change or reboot, the next 7 days are rescheduled
  (rolling window).

**US9. Interplay with workouts and bodyweight.**
- Bodyweight is read-only on Diet (the suggestion only), and recorded only in Profile.
- No diet figure appears on History, Profile, the summary card or the share card. No workout figure
  appears on Diet. Training days from Schedule are not marked on the week strip in V1 (Q7).

**US10. Edit the past / week rollover.**
- Earlier days of the current week are editable (plan and ticks). On Monday the strip moves to the
  new week. Last week's plan and ticks are kept but not shown (D6, Q3).
- If the app is open across midnight, the "today" highlight and tickability update when the app
  resumes. Today is not cached for the life of the process.

**US11. Export.** *As a user, my diet data is in the export.*
- The `ExportScreen` JSON gains `diet`: `proteinTargetG`; `planVersions[]` (`effectiveFrom`,
  `items[]` of `weekday`, `slot`, `foodId`, `name`, `servings`); and `eaten[]` (`date`, `slot`).
- No totals, no protein per day, no "to go" (entered data only). Food names travel next to their
  ids, the way exercise names do.
- The counts card on `ExportScreen` / `DeleteAllDataScreen` adds "N foods planned".

**US12. Delete all data.**
- `wipeAllData` empties every diet table and the target, and cancels every scheduled notification
  (once S7 has shipped). After the reboot, Diet shows US1.

**US13. Error states.**
- If the catalogue asset fails to load or validate at boot, fail loudly in debug. In release,
  Diet shows "Food list unavailable. Reinstall the app" and the other tabs keep working. The
  exercise library is not affected.
- If a plan row refers to a food id the current build no longer ships, the validator must prevent
  that (§4). Defensively, the row renders "Unknown food", counts 0 g and can be removed.

---

## 3. Navigation placement

| Option | For | Against |
|---|---|---|
| **A. Fifth tab, Diet (Workout · Muscles · History · Diet · Profile)** | Used daily (3–4 times with reminders), so it earns a root. Notification taps land on a tab root, which fits ADR 0003's single-navigator invariant (a tab switch with an empty stack). `GlassTabBar` geometry is already n-generic (`slot = width / labels.length`). It matches all three drafts | ADR 0004 called four the ceiling. Slots shrink from about 83 to 67 pt at 375 pt width. Profile's index moves 3 → 4 |
| B. Third Profile segment (Personal · Schedule · Diet) | No ADR 0004 change. The plan is "authored", which fits Profile under the placement rule | A daily surface buried behind a tab and a segment. Deep links must open a segment. The segmented control at three labels is cramped. Profile turns into a junk drawer |
| C. Inside Workout | — | ADR 0006: Workout is exercise-first. Diet is unrelated to a session |
| D. Pushed from the History or Profile header | No tab change | Hard to find. Notification taps land on a pushed route, which is exactly the per-tab-stack problem ADR 0003 avoids |

**Recommendation: A, fifth tab, in the drafts' order.** ADR 0007 restates that a fifth tab changes
the bar's *contents*, not its *reach*: the bar still shows only at L0, the open session is still the
Workout root, and one root `Navigator` is still correct.

**Required checks:**
- Labels at 10.5 pt must fit on one line on the smallest supported phone (17e) at 1.3× text scale.
  Add a golden or geometry test.
- Every 48 pt tap target holds.
- Drag-to-switch still lands in the right slot.

---

## 4. Data model

### Stored (preferences and facts the user typed). Schema **v6**, one step

All dates are `TEXT YYYY-MM-DD` via `LocalDateConverter`, the same as `Sessions.performedOn` and
`TrainingPlanEntries.effectiveFrom`.

| Table / column | Columns | Rules |
|---|---|---|
| `DietPlanVersions` | `effectiveFrom TEXT PK` (always a Monday) | The dated series, the same shape as `TrainingPlanEntries` (ADR 0005 §2). A version is the whole week's plan |
| `DietPlanItems` | `id TEXT PK`, `effectiveFrom TEXT → DietPlanVersions ON DELETE CASCADE`, `weekday INT`, `slot TEXT`, `foodId TEXT`, `servingsHalves INT`, `position INT` | `CHECK weekday BETWEEN 1 AND 7`. `CHECK slot IN ('breakfast','lunch','snack','dinner')` (stored by name, never by index). `CHECK servingsHalves BETWEEN 1 AND 8` (0.5–4 as integers, so there is no float drift). `UNIQUE (effectiveFrom, weekday, slot, foodId)`. **No FK on `foodId`**: the catalogue is an asset, as template ids are Dart consts |
| `MealTicks` (if Q1 = keep) | `date TEXT`, `slot TEXT`, PK `(date, slot)` | The row's presence means eaten. Hard delete on untick. "Not in the future" can't be a CHECK (CHECK has no "today"), so the store rejects it and a test proves it |
| `Settings.proteinTargetG` | `INT NULL`, `CHECK NULL OR 1..400` | Null means never set (the same convention as `bodyGender`). Not a dated series (Q2) |

**Copy-on-write rule (in `DietPlanStore`, one transaction):** an edit in week W looks for a version
with `effectiveFrom == monday(W)`. If there isn't one, it copies the latest version before W into a
new version at `monday(W)`, then applies the edit. Versions before `monday(W)` are never written.
**No update or delete path touches an older version**, the same guarantee `TrainingPlanStore`
gives.

**Migration (`app_database.dart`):** bump `schemaVersion` to 6 and add
`if (from < 6) { createTable(dietPlanVersions); createTable(dietPlanItems); createTable(mealTicks); addColumn(settings, settings.proteinTargetG); }`.
The guard is a range, the step is pure DDL in one transaction and idempotent, and nothing is
numbered below 6. Add a v5→v6 test to `test/app_database_migration_test.dart` (open a
real v5 DB with rows, upgrade, assert the rows survive and the new tables exist). Re-run
`dart run build_runner build` and commit `app_database.g.dart`. Update the class doc comment
("Schema version 6 …").

**Reminder preferences: schema v7, in S7, not now.** Proposed: `MealReminderPrefs` (one row, PK
pinned like `Settings`): `enabled BOOL`, `summaryOn BOOL`, `summaryMinute INT`, and per-slot
`on`/`minute`, with `CHECK minute BETWEEN 0 AND 1439`. **Coordinate with the ADR 0005 notifications
ticket.** The Schedule's Remind me switch is in-memory today and also needs storage. Whichever
lands first takes the next version number, and the other goes above it.

### Derived on read, never stored

| Value | Pure function (`lib/src/data/diet_derived.dart`) |
|---|---|
| Plan in effect on a date | `planVersionInEffectOn(versions, date)`: the latest `effectiveFrom ≤ monday(date)`. Reuse `startOfWeek` from `training_plan.dart` |
| Slot protein | `Σ food.proteinPerServing × halves / 2` |
| Day planned / eaten / to go | Planned = Σ slots. Eaten = Σ ticked slots. To go = `max(0, target − planned)` |
| Week strip meters | planned ÷ target, clamped to 0..1 |
| Tickable | `date ≤ today && date ≥ monday(today) && slot non-empty` |
| Suggested target | `roundTo5(multiplier × weightInEffectOn(today))`. Null without a bodyweight |
| Reminder bodies | Built from the plan at scheduling time and never persisted in the DB |

Display: protein per serving keeps one decimal in data. Totals render as whole grams (round half
up, applied once to the total, never per row). Units are g for protein, and grams per serving shown
next to household units. No unit toggle.

### Food catalogue

- **Bundled asset `assets/foods/foods.json`**, produced by `assets/foods/food_catalogue.py` (the
  source tables, one module per food family, like `assets/exercises/content_*.py`). Checked by
  `assets/foods/validate_food_catalogue.py`. Add it to `pubspec.yaml` assets and to the CI
  generators job beside the exercise validator. `git diff --exit-code` already catches drift.
- **Fields:** `id` (lower-case-hyphen, stable), `name`, `aliases[]` (e.g. "dahi" for curd),
  `dietType ∈ {veg, egg, nonVeg}`, `servingLabel`, `gramsPerServing`, `proteinPerServingG` (one
  decimal), `source` (an IFCT 2017 food code or table plus page), `reviewedBy`.
- **Validator rules:** unique ids; every field present; protein ≤ grams; `proteinPerServingG > 0`;
  `dietType` in the enum; source non-empty. **Ids are never removed:** compare against the committed
  `assets/foods/food_ids_ever.txt`, the same guarantee that keeps old plan rows resolvable.
- **Reviewed copy.** The values carry nutrition risk, the same way exercise copy carries injury
  risk. Add to `CLAUDE.md` Generated data: never hand-edit, regenerate or "fix" values without
  review.
- **No snapshot of protein on plan rows.** A corrected value *should* flow into the plan. Unlike
  `loadType`, a later build changing it does not invert a meaning. Past-week eaten totals shift, but
  nothing displays them (Q3).
- Loaded at boot beside the exercise library (`main.dart` `_bootFrom` record). Exposed as a
  `foodIndexProvider` (`lib/src/data/food_index.dart`) overridden with the parsed index, as
  `exerciseIndexProvider` is.

### Export and wipe touch points
- `lib/src/data/data_export.dart`: add a `diet` key (US11). Adding a key needs no
  `kExportFormatVersion` bump; renaming or removing one does.
- `lib/src/data/data_reset.dart`: delete `mealTicks`, then `dietPlanItems`, then `dietPlanVersions`
  (children first). `settings` is already wiped. In S7, also cancel all notifications.
- `test/data_export_reset_test.dart`: replace the hand-written table list with
  `database.allTables`, so a future table that is not wiped fails the test. Add "stores nothing
  derived" assertions for diet (no `planned`, `eaten`, `toGo` or `total` keys).
- `lib/src/ui/data_screens.dart` `_DataCounts`: add the diet count.

---

## 5. State and UI

### Riverpod (no codegen), following `training_plan.dart`

| Provider | Kind | File |
|---|---|---|
| `foodIndexProvider` | `Provider<FoodIndex>`, overridden at boot | `lib/src/data/food_index.dart` |
| `initialDietPlanProvider`, `dietPlanLogProvider` | Boot seed + `Notifier<List<DietPlanVersion>>` (`add`, `setServings`, `remove`; copy-on-write in the store) | `lib/src/data/diet_plan.dart` |
| `initialMealTicksProvider`, `mealTicksProvider` | Boot seed + `Notifier<Set<(LocalDate, MealSlot)>>` (`toggle`) | `lib/src/data/meal_ticks.dart` |
| `proteinTargetProvider` | `Notifier<int?>` | `lib/src/data/diet_plan.dart` |
| `dietTodayProvider` | Reuse or generalise `planTodayProvider` so a midnight rollover refreshes it on resume (US10) | `lib/src/data/training_plan.dart` |
| `dietDayProvider` | `Provider.family<DietDay, LocalDate>`: slots, planned, eaten, toGo, tickable | `lib/src/data/diet_derived.dart` |
| `dietWeekProvider` | `Provider<List<DietDayMeter>>` for the strip | same |
| `suggestedTargetProvider` | `Provider<int?>` from `weightInEffectProvider` | same |
| `dietSelectedDayProvider`, `foodFilterProvider` | In memory, never stored | `lib/src/ui/diet_root.dart` |

Every visible number comes from `dietDayProvider`. An edit or tick invalidates it automatically,
and there is no manual refresh path.

### Screens → prototype → files

| Screen | Prototype | New file | Builds on |
|---|---|---|---|
| D1 Diet landing (L0 root) | `today()` + empty-state phone | `lib/src/ui/diet_root.dart` (body), `diet_day_card.dart`, `diet_slot_card.dart`, `diet_week_strip.dart` | `L0TabSpec` in `l0_shell.dart` (with bell `actions`); `screenScrollPadding`; `EmptyState` (+ `EmptyStateGlyph.bowl`); `GhostButton`. The week strip follows `_DayChip` / `PlanDot` in `schedule_pane.dart`. Promote those to shared widgets rather than copying them |
| D2 Add food (pushed) | `addFood()` | `lib/src/ui/food_picker_screen.dart` | `AppScreen.pushed`; `muscle_search_field.dart` for the search field; chip style from `personal_details_screen.dart` `_GenderChip` (outlined) |
| Add / edit sheet | `sheet()` add/edit | `lib/src/ui/food_serving_sheet.dart` | `StepperField(step: 0.5, decimals: 1)`. **Needs a `min` parameter** (it clamps at 0 today). Remove in `danger` |
| D3 Target (pushed) | `target()` | `lib/src/ui/protein_target_screen.dart` | `StepperField` or the `_WeightField` pattern in `personal_details_screen.dart` |
| D4 Reminders (pushed, S7) | `remind()` + explain sheet | `lib/src/ui/meal_reminders_screen.dart` | Promote `_SwitchRow`, `_Switch`, `_TimeRow` and `_ExplainSheet` from `schedule_pane.dart` to a shared file, used by both |
| Tab glyph | bowl path `M4 11h16a8 8 0 0 1-16 0z…` | `TabGlyph.diet` in `lib/src/ui/tab_glyph.dart` | `GlassTabBar.labels/glyphs`, `kL0TabCount = 5` in `tab_index.dart` |
| Diet-type marker | `DT()` square + dot / egg / triangle | `lib/src/ui/diet_type_glyph.dart` (CustomPainter) | `textSecondary` outline, paired with its text label |

**Index hygiene before the fifth tab lands.** Tests hard-code `GlassTabBar.itemKey(3)` for Profile
(`test/l0_shell_test.dart:384`, `integration_test/taste_shots_test.dart:245,268`), and the shell
special-cases `index == 0`. Introduce an `L0Tab` enum (`workout, muscles, history, diet, profile`)
used by `tab_index.dart`, `l0_shell.dart` and all tests, so inserting Diet doesn't silently retarget
Profile taps.

### Palette (closed: `00` §12; `test/theme_palette_test.dart` enforces it)

| Diet meaning | Role | Note |
|---|---|---|
| Eaten (bar layer, tick when on, legend swatch) | `accentStrong` | "Active / done". One accent on screen: the tick and the bar layer are the same meaning |
| Planned (bar layer, meters) | `textMuted` on `mutedSurface` | |
| Diet-type glyph, serving meta | `textSecondary` / `textMuted` | Shape + word, never colour alone |
| Primary action (Add, Save, Plan Monday) | `liquid` gradient | Exactly one per view |
| Remove from slot | `danger` | Text only, never a fill |
| **Not used** | `accentLight` | Reserved for secondary muscle. Do not reuse it for "egg" or "planned" |

No green/red veg dots and no new colours. A request for one is a user decision (Q12).

### Taste rules that bite here
- Sentence case everywhere: "Repeat on", "Mon" (not "MON"). Nothing under 12 pt. The prototype's
  9.5–11.5 px captions go up to 12. Tabular figures on every gram value.
- No em/en dash separators (use a period or comma). A middle dot is allowed in lists.
- 16 radius for cards, capsule for chips and buttons. Tick, chips and day chips are outlined.
- Platform font (Inter is undecided and must not be bundled or fetched).
- Every list has an `EmptyState`. Disabled says why nearby. Tap targets ≥ 48 pt. The last slot
  card clears the floating bar (`screenScrollPadding`).
- Header pinned via `AppScreen` (`test/app_screen_test.dart`). The week strip scrolls with the body
  and is not part of the header.

---

## 6. Phased build order (vertical slices; each one ships green)

S0 is paper. From S2 on, every slice is usable, and there is no table without export and wipe
coverage.

| Slice | Delivers | Touch points | Tests |
|---|---|---|---|
| **S0. Decide** | Owner answers §7. ADR 0007 written and accepted. Doc amendments (§1 table). `diet.html` re-skinned to ONE DAY and taste rules. PRD/userflow marked accepted | `docs/adr/0007-diet-tab.md`, `docs/01`, `docs/00`, `CLAUDE.md`, ADR 0004/0005 status lines, `prototypes/diet.html` | — |
| **S1. Catalogue** | `foods.json` with about 60–100 reviewed foods, generator, validator, CI step, `FoodIndex` at boot. Nothing visible yet | `assets/foods/*`, `pubspec.yaml`, `.github/workflows/ci.yml`, `lib/src/data/food_index.dart`, `lib/main.dart` | `test/food_index_test.dart` (parse, search/aliases, filter semantics, sort). Extend `test/shipped_data_test.dart`: asset present, ids unique, every food sourced |
| **S2. Data layer** | v6 tables, migration, `DietPlanStore` (copy-on-write), `MealTickStore`, target column, notifiers, `diet_derived.dart`. Export and wipe in the same slice | `lib/src/data/app_database.dart` (+ `.g.dart`), `diet_plan.dart`, `meal_ticks.dart`, `diet_derived.dart`, `data_export.dart`, `data_reset.dart`, `lib/main.dart` boot overrides | Unit tests: `test/diet_derived_test.dart` (slot/day sums, half servings, rounding once, to-go clamp, tickable window incl. Sunday→Monday rollover, version-in-effect, suggestion rounding, no bodyweight = null). `test/diet_plan_store_test.dart` (copy-on-write never writes an older version; replace-on-duplicate; CHECKs reject 0 and 9 halves, bad slot). `test/meal_ticks_test.dart` (future date rejected). Migration test v5→v6. `test/data_export_reset_test.dart` (diet keys present, nothing derived, `allTables` empty after wipe) |
| **S3. Tab + core loop** | `L0Tab` enum refactor, then the fifth tab with glyph. D1 for the selected day (today), empty state, D2 picker, add sheet (single day), edit sheet (servings, remove + undo). No target, no ticks yet: the day card reads "N g planned" | `tab_index.dart`, `glass_tab_bar.dart`, `tab_glyph.dart`, `l0_shell.dart`, `empty_state.dart`, `stepper_field.dart` (`min`), new UI files in §5 | Widget tests: `test/diet_root_test.dart` (empty → Plan Monday → D2; slot totals; edit/remove/undo); `test/food_picker_test.dart` (search, chips, sort, no-match state); `test/food_serving_sheet_test.dart` (0.5 floor, 4 ceiling, live protein). Update `test/l0_shell_test.dart`, `test/glass_tab_bar_test.dart` (5 slots, drag lands correctly, labels fit at 17e × 1.3), `test/tab_glyph_test.dart`, `test/tab_roots_test.dart`. Run `test/theme_palette_test.dart` |
| **S4. Week** | Week strip, day switching, Repeat on | `diet_week_strip.dart`, `food_serving_sheet.dart` | Widget: switching days changes the card; Repeat on writes N rows in one transaction; no-day-selected disables Add |
| **S5. Target** | D3, suggestion, day card bar and copy, strip meters | `protein_target_screen.dart`, `diet_day_card.dart` | Widget: suggestion only with bodyweight; tapping fills but doesn't save; clearing goes back to the no-target copy; copy-ban test (no "behind/missed/failed/over") over every diet string |
| **S6. Eaten ticks** (if Q1 = keep) | Tick per slot, eaten layer, legend | `diet_slot_card.dart`, `diet_day_card.dart` | Widget: tick absent on future days and empty slots; eaten updates in place; editing Monday's plan on Wednesday changes Monday's eaten (D7, documented behaviour) |
| **S7. Reminders** | **Only after the ADR 0005 notification ticket ships the plugin.** D4, v7 prefs table, scheduler (7-day rolling window, inexact on Android, reboot-safe, ≤ 64 pending on iOS including training reminders), notification tap → Diet today, wipe cancels all | `meal_reminders_screen.dart`, `lib/src/data/meal_reminders.dart`, shared switch/explain widgets, `app_database.dart` v7, `data_reset.dart` | Unit: `test/meal_reminder_schedule_test.dart` (empty slot = none; empty day = no summary; ticks never change the set; bodies match the template; rolling window count). Widget: explain-first, then permission; denied still works. Migration v6→v7 |
| **S8. Polish and walks** | Turtle-taste pass on small + large iPhone. Debug-only sample diet in `sample_history_seed.dart` so the shots aren't empty | `lib/src/data/sample_history_seed.dart`, `tool/taste_shots.sh` | Add a `diet` section to `integration_test/taste_shots_test.dart` (empty, landing, picker, picker-empty, add sheet, edit sheet, target with and without suggestion, reminders). Add the Diet walk to `integration_test/sweep_test.dart` (no framework errors). Add one Diet round trip to `integration_test/workout_flow_test.dart` to prove the tab switch keeps an open session intact |

Notes:
- Per the user's standing rules: no commits unless asked, and never run `dart format` over `lib/`
  or `test/`.
- S3 can ship without S4–S6, but **S7 cannot ship before ADR 0005's notifications.** If those slip,
  Diet ships without D4 and the bell stays out of the header (no inert bell).

---

## 7. Risks and open questions (each with a recommended default)

### Risks

| Risk | Mitigation |
|---|---|
| Wrong protein values mislead users | IFCT 2017 citation per food, a named reviewer, a validator, "reviewed copy" rule in `CLAUDE.md` |
| Scope creep into calories/macros/logging | ADR 0007 states protein-only. §1 lists the cuts explicitly |
| Product identity drift (`01` says "not a nutrition app") | Owner signs ADR 0007 before any code |
| Bar crowding at five tabs | Geometry and text-scale tests at 17e × 1.3 (S3) |
| Tab index shift breaks Profile routing silently | `L0Tab` enum refactor first (S3) |
| A table added without export/wipe | `allTables`-driven wipe test (S2) |
| Notifications blocked on an unbuilt dependency | S7 gated; no inert bell |
| iOS 64-pending cap with training + meal reminders | 7-day rolling window: ≤ 35 meal + 7 training |
| Midnight rollover shows the wrong "today" | Today re-read on resume (US10) |
| Users read it as medical advice | Disclaimer on D3; no clinical claims; "Not for" list stays |

### Open questions for the owner

1. **Keep the "eaten" tick?** It is the feature's closest brush with "no logging food" in `01`.
   *Default: keep it as specified (optional, one tap per slot, no quantities). Build it last (S6) so
   it can be dropped without rework.*
2. **Is the protein target a dated series like bodyweight?** *Default: no. Use one nullable column.
   Nothing shows past weeks, so a change can only re-colour this week's meters. Revisit if a diet
   history view is added.*
3. **Keep the dated plan series when no screen shows past weeks?** *Default: yes. It costs little,
   matches ADR 0005, keeps exported ticks meaningful, and leaves room for a "last week" view. Do not
   build that view in V1.*
4. **A mid-week plan edit changes earlier days' eaten totals this week (D7). Is that acceptable?**
   *Default: yes. It reads as the user correcting those days. Drop the prototype's "never rewrites
   what you ticked" line.*
5. **What does the Egg chip mean?** *Default: Egg = veg + egg ("eggetarian"), the way Indian users
   describe their diet. Veg = veg only. Non-veg = non-veg foods only. Label the Egg chip "Egg" with
   a short caption "Veg and egg foods" in the list.*
6. **Suggestion multiplier and source; target bounds.** *Default: 1.6 g/kg, rounded to the nearest
   5 g, citing Morton et al. 2018 (Br J Sports Med meta-analysis, plateau about 1.6 g/kg/day for
   resistance training) and the ISSN position stand (1.4–2.0 g/kg). One multiplier for beginners
   and regulars. Field bounds 1–400 g. A reviewer must confirm the citation.*
7. **One plan for every week, or training-day vs rest-day plans, or training-day markers on the
   strip?** *Default: one plan, no markers in V1.*
8. **Custom foods?** *Default: no in V1 (PRD). Missing foods are collected from testers and added to
   the generator.*
9. **Remove a planned food: confirm dialog or undo?** *Default: undo snackbar. A confirmation dialog
   (`destructive_confirmation.dart`) is for losing workouts or all data, not for one plan row.*
10. **Notification "Mark eaten" action?** *Default: no for V1.*
11. **Re-skin `prototypes/diet.html` to ONE DAY and move it into `screens.html` (PRD milestone 3)
    before build?** *Default: re-skin it in place now (the palette, type sizes and case are stale).
    Fold it into `screens.html` in S8.*
12. **Any colour for diet types (the Indian green/red dot convention)?** *Default: no. Keep the
    closed palette and use the shape glyph with a text label.*
13. **Catalogue size and reviewer.** *Default: about 80 foods across veg/egg/non-veg at launch, with
    a nutrition-literate reviewer named in `reviewedBy`. Do not ship values nobody reviewed.*
14. **Should diet data be in the export?** *Default: yes. Export promises "everything you entered".*
