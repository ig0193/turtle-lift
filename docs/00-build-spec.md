# 00 — Build spec

**Rules only. No rationale.** Every section links to the doc that explains *why*; read that before changing a rule, not before implementing it.

| Doc | Contains |
|---|---|
| `00-build-spec.md` | This file. What to build. |
| `01-app-idea.md` | Scope, data model, muscle taxonomy, palette, and the reasoning behind every rule here. |
| `02-workout-tab-userflow.md` | Workout tab flow + mockups. |
| `03-muscle-groups-tab-userflow.md` | Muscle Groups tab flow + mockups. |
| `04-profile-tab-userflow.md` | Profile flow + mockups. Profile is the fourth tab (Personal | Schedule); history is its own tab. |

Conflict resolution: if this file disagrees with `01`–`04`, **`01`–`04` win** — this is a digest, not a source of truth. Report the conflict.

---

## 1. Shipped files — use these, do not regenerate by hand

| Path | Contents |
|---|---|
| `body-diagrams/body-diagram-front.svg` | Male front, 13 elements / 12 sub-groups |
| `body-diagrams/body-diagram-back.svg` | Male back, 9 |
| `body-diagrams/body-diagram-front-female.svg` | Female front, 12 |
| `body-diagrams/body-diagram-back-female.svg` | Female back, 9 |
| `body-diagrams/muscle_taxonomy.dart` / `.json` | Parent groups, sub-groups, labels, segment mapping |
| `body-diagrams/generate_muscle_taxonomy.py` | Regenerates taxonomy; self-validates against SVGs |

Re-run the taxonomy generator after any SVG change. It fails loudly on drift.

Full viewBoxes (also in `kFullViewBox`):

| Asset | viewBox |
|---|---|
| `front_male` | `0 0 700 1324` |
| `back_male` | `0 0 712 1324` |
| `front_female` | `0 0 700 1268` |
| `back_female` | `0 0 704 1252` |

Male and female assets have different coordinate spaces — never assume a value computed for one applies to the other.

---

## 2. Data model

**Session**

| Field | Type | Rules |
|---|---|---|
| `id` | id | |
| `title` | string? | Optional, max 40 chars. May be empty in storage, never displayed empty — see §6. |
| `performedOn` | **local calendar date** | No time, no timezone. Defaults today. Editable. Clamped ≤ today. Drives streak, history order, date labels. |
| `loggedAt` | timestamp | Internal only. Tiebreaker when two sessions share `performedOn`. Never shown. |
| `templateId` | id? | `null` = ad-hoc session. |

**SessionExercise** — `exerciseId`, `order`, `loadType` (snapshotted at add time), and a stored `markedDone` flag.

⚠ **Conflict, resolved.** This line used to give `SessionExercise` a stored `state ∈ not_started | in_progress | done`, which contradicts §3 and `01` §Derived values: delete every set from an `in_progress` exercise and the stored state is simply wrong. Only the user's Mark-exercise-done tap is stored; the tri-state the list renders is derived from that flag and the sets. `loadType` *is* stored, and is the one exception worth stating — it lives in regenerated content, so a set row whose meaning is resolved at read time would be reinterpreted by a later build, and an assisted record read as a maximum is silently backwards.
**SetEntry** — `completed`, plus fields determined by the exercise's `loadType`:

| `loadType` | Count | Required | Optional | Set complete when | PB metric |
|---|---|---|---|---|---|
| `weighted` | 196 | `weightKg`, `reps` | — | `reps > 0` | `(weightKg, reps)` |
| `bodyweight` | 47 | `reps` | `addedKg` | `reps > 0` | `(addedKg, reps)` |
| `assisted` | 3 | `reps` | `assistKg` | `reps > 0` | `(-assistKg, reps)` ⚠ **lower is better** |
| `timed` | 14 | `durationSec` | `weightKg` | `durationSec > 0` | `(weightKg, durationSec)` |

All inputs are unsigned positive numbers; the sign is carried by the type. `assistKg` is its own field, never a negative `addedKg`. Display formats, prefill rules and the duration input spec are in `01` §Set logging by loadType.

**Exercise** (library) — `id`, `name`, `equipment`, `loadType`, `primary[]`, `secondary[]`, and four content fields rendered as separate labelled, collapsible blocks on Exercise Detail. The table below is the data order; the **render order is Common mistakes, Setup, Posture, Execution** (§10):

| Field | Contains |
|---|---|
| `setup` | Equipment position and starting position. Bench angles, grip widths, foot placement, in numbers. |
| `posture` | Body alignment held throughout — chest up, ribs down, flat back, braced core. |
| `execution` | The movement, with tempo and **breathing** (inhale/exhale) on every entry. |
| `commonMistakes` | The one or two errors that matter, injury risks named plainly. |

Average 76 words per exercise across all four. Every entry mentions breathing; 198 of 260 include a specific number. **No `alternatives` field** — the sub-muscle-group exercise list serves that purpose. Source: `exercises/exercises.json`, 260 entries, validated by `validate_exercise_library.py`.

**Template** — name, `isPredefined`, and an **ordered list of exercise ids** (`docs/adr/0006-workout-tab-is-exercise-first.md`). Never store muscles: the muscle line on a row is derived from the exercises' primary muscles. Starting one **copies** the list into the session; nothing a session does writes back.

**No muscle-level state exists in the model.** → `01` §Muscle training state.

---

## 3. Derived values — compute on read, never store

`streak` · exercise count · set count · personal bests · **per-session PB count** · calorie estimate · resolved title · a template row's muscle line.

**No lifted-volume (kg) metric anywhere in V1** — it cannot include bodyweight or timed exercises. Set count is the headline **volume proxy** in its place. → `01` §Derived values. (It stands in for the banned kg figure; it is not an instruction about which stat renders largest.)

Deleting or editing a session must change all of the above automatically, including the inline "Last time: 22kg × 10" hint. Do not introduce a stored counter. → `01` §Derived values.

---

## 4. Muscle taxonomy

Load from `muscle_taxonomy.dart`. **12 parents, 19 sub-groups, 1 mapping exception, 0 orphan segments.**

- A template row's muscle line is derived from its exercises and the taxonomy at render time.
- Resolve diagram regions via the `segments` list, not by string-matching ids.
- `back/upper`, `forearms/forearms`, `calves/calves` each fill segments in **both** views. Normal.
- **`shoulders/side-delt` → `shoulders/front-delt`, FRONT VIEW ONLY.** The only exception. Never map it to `rear-delt`.
- Traps is `back/upper`, not `shoulders/*`, on both views.
- **No accordion anywhere.** The Workout tab's nested muscle list (the only accordion, for chest, back, shoulders and abs) was removed with `docs/adr/0006`; the Muscles tab never had one (§10).

→ `01` §Muscle group hierarchy.

---

## 5. Body diagram rendering

- Asset pair chosen by Profile gender field. Default male. Switching applies app-wide immediately.
- **One diagram treatment everywhere: full body, unmodified viewBox.** There is no zoomed or cropped view anywhere in V1. Used on Workout Overview, Muscle Groups landing, Exercise Detail, summary and session cards.
  - **The crop system has been deleted** (`muscle_crops.json`, `muscle_crops.dart`, `generate_muscle_crops.py`). Its last two consumers both stopped needing it: Exercise Detail moved to full body during prototyping, because crops produced unreadable letterbox strips and lost the anatomical context that makes the diagram educational, and the sub-muscle-group selection screen was deleted outright (§10). **Do not reintroduce cropping.** `03`'s exercise-detail mockup note used to call for a zoomed viewBox; it has been corrected.
- Exercise Detail: **full-body** diagram. If relevant muscles span both views, show **both side by side**, each full body. If one view covers everything, show one, centred.
- Fill colours: primary `#D85A30`, secondary `#F0997B`, untrained `#241F19`.
- **Uniformity rule:** every muscle map comes from these SVGs. No screen gets its own simplified diagram. Mockup SVGs in `02`–`04` are layout references only.
- **No body figure other than the four traced diagrams.** Workout Summary and Session Detail use the same anatomical diagram as everywhere else — no zone-lit human figure exists and none should be built.
- **Mascot is a turtle** (`mascot-brief.md`). It is a decorative companion, not a body diagram, and never replaces a muscle map. Four states: resting, lifting, pleased, hidden. Appears on workout overview (52px corner tile), celebration, empty states, app icon. **Not on the share card.** **Never reacts to inactivity** — no decay, no guilt, no notifications, no achievement on the tap easter egg. Not a blocker; build last.
- **Share card view rule:** show only the view(s) containing trained muscles, side by side when both apply. Same conditional already used on Exercise Detail. Never render an empty second diagram.
- Label the front shoulder segment **"Shoulder (front)"**, not "Front delt".

---

## 6. Session title — resolution order

1. `session.title` if non-empty
2. Template name
3. Single exercise's name (quick logs)
4. Primary muscle groups trained, comma-separated

Never auto-generate a time-of-day title. Prefill with template name on template path; empty on ad-hoc. Inline-editable on the summary card. Max 40 chars.

---

## 7. Streak

```
streakAsOf(date) -> int
  walk back from `date` through distinct performedOn dates,
  chain while gap <= 3 days
```

- Tolerance **3 days**.
- Counts any session with **≥1 completed set**, including quick logs.
- Profile hero = `streakAsOf(today)`. Past session card = `streakAsOf(session.performedOn)`.
- **Must decay against today**, not just against stored data.
- Never stored.
- Optional in-app hint on the final grace day. In-app only; reminders are separate and user-scheduled (`docs/adr/0005-schedule-and-opt-in-notifications.md`).

---

## 8. Calorie estimate

`kcal = (MET × 3.5 × bodyweightKg / 200) × minutes`, `minutes = totalSets × 42.5 / 60`

| Sets | Tier | MET |
|---|---|---|
| 1–9 | Light | 3.5 |
| 10–20 | Moderate | 5.0 |
| 21+ | Vigorous | 6.0 |

- Hidden entirely until bodyweight is set; that slot shows an "add weight to see calories" prompt linking to Profile.
- Display as `185 kcal`, single number, with an (i) icon.
- ⚠ The kcal figures in the `02` mockups (185, ~140) are **illustrative and do not match this formula**. Do not use them as test fixtures.

---

## 9. Workout tab

**Model:** a session is a list of exercises; a template is a pre-filled list; ad-hoc is an empty one. Muscles describe the list (the live map) and never navigate it. → `docs/adr/0006-workout-tab-is-exercise-first.md`.

**Landing** — a search field (by name, over templates and exercises), **My templates** (a rail; absent when none), **Ready-made** (the eleven predefined, a two-column grid, fixed order), `Manage templates`, and a **pinned Start workout bar** above the tab bar. **No split filter**, nothing stores a split. A template tile shows its name, a derived muscle line and its exercise count; tapping it opens a **preview sheet** (the exercises, `Start workout`, `Cancel`) — two taps to start. A search result for an exercise starts an ad-hoc workout with it.

**Start** — opens the session on a **ready view**: map at full size, `N exercises planned` / `Nothing logged yet`, one **Start logging** button, Discard (no Finish). Start logging opens the **exercise picker** (tall sheet: search, muscle chips as a filter, `IN THIS WORKOUT` first). "Started logging" is in-memory only, and is also true once anything is written.

**Session screen** (after Start logging)
- Pulsing `WORKOUT IN PROGRESS` strip (one pulse, no loop) with the **clock**; editable title (no caption line); editable date, prominent when ≠ today; `N of M done`.
- **Body map is the hero** and shrinks in steps as the list grows. It fills live: primary `#D85A30`, secondary `#F0997B`; muscles the list plans to train and has not worked are **outlined**.
- `KEEP LOGGING`: one flat exercise list for both paths, tri-state `To do / In progress / Done` (derived), the first not-done row tagged `UP NEXT`. `+ Add exercise`. Finish (primary) + Discard (secondary, confirm dialog).
- **No muscle list, no `trained` tick, no template lock.** Any exercise can be added to any session.

**Clock** — display-only elapsed time. **Never stored**; shown nowhere but the live screen (not History, not the summary or share card). Counts from `loggedAt`; shows only when `performedOn` is the day the session started and it is under six hours old.

**Save as template** — on the finished workout's summary: names it, keeps the exercises that have completed sets, in order. The only way a user's own templates are made; rename / duplicate / delete stay on Profile.

**Finish** — available any time. **A session with 0 completed sets must not save.**

**Session persistence** — an active session persists indefinitely; never auto-discarded. Returning to the Workout tab shows the session in place of the landing; no Resume card. Starting a new workout auto-saves the open one (>=1 completed set, keeping its **original `performedOn`**, with a toast) or discards it silently (0 sets). One active session at a time.

**Exercise tap → set logging directly.** Info button in the logging header reaches Exercise Detail. Exception: `timesPerformed == 0` and no sets written yet → land on Exercise Detail first (applies to a row already on the list as well as to one being added).

**Set-logging screen order:** sets → Add set → Mark exercise done → Recent (last 2, all sets shown per session) → See all N sessions.

→ `02`.

---

## 10. Muscle Groups tab

**Pure reference. No logging anywhere in this tab, and nothing in it reads session history.** Every personal figure is **deferred to a later plan** — see `03` §What ships, and what is deferred, which keeps those rules written down. Do not build any of them here.

**Landing** — search field, front/back view control, the full-body map, then **all 19 sub-group rows** as one flat list ordered by parent group, each showing how many exercises name it as a *primary* muscle.
- **Every segment on the map renders muted.** No fill stands for training. The diagram takes its per-segment fill as a caller-supplied parameter, so the deferred trained/untrained colour is added by the caller, not by reopening the widget.
- `shoulders/side-delt` has no artwork; the list is its only route, and its row says so.

**Browse is one tap.** A segment tap and a row tap both open that sub-muscle group's exercise list — **no muscle-group selection screen and no sub-muscle-group selection screen exist.** They were **deleted, not deferred**: of 42 segments exactly one (`shoulders/front-delt`, which also carries `shoulders/side-delt`) is ambiguous, so a picker for all 42 earned nothing.
- **That one segment opens a two-option bottom sheet** — Front delt / Side delt — and pushes the chosen one. Dismissing opens nothing. Read the ambiguity from the taxonomy; never hard-code the pair.

**Search** — one field over **three vocabularies**: 260 exercise names, 19 sub-group labels, 8 equipment values. Every result is labelled with its kind. Exercise → detail; muscle → that sub-group's exercise list; equipment → **the equipment-filtered list, which is a search destination only — nothing browses to it**. A query matching no exercise name still renders the full muscle list and the full equipment list, each headed. Never an empty result screen.

**Exercise list** (per sub-muscle group) — vertical list of compact cards: name and equipment chip. Primary involvement only. Not a horizontal carousel: this is a comparison decision ("which of these can I do right now") and it needs every option visible at once. No `alternatives` field — this list is the alternatives. **The derived `Last: 22kg × 8` line is deferred.**

**Exercise detail** — one screen, in this order: equipment + load type, primary/secondary muscle chips, diagram(s), the four reviewed content fields, substitutes.
- Diagram(s): **full body, read-only**. Both front and back side by side **only** when the relevant muscles span both views — primaries *and* secondaries decide that. Otherwise one, centred.
- **The four content fields are collapsible rows: Common mistakes first and expanded, then Setup, Posture, Execution, collapsed.** Rendered verbatim — reviewed copy, never rewritten, summarised, truncated or reflowed.
- **Substitutes rail** — exercises sharing **any** of this one's primary sub-groups, different equipment first, capped at 8. Titled after the muscle only when there is exactly one primary; neutral otherwise.
- **No history block of any kind** — no Best/Last/Times tiles, no recent log, no PB badge, no `assisted` banner, and **no "You haven't logged this yet" line**. Deferred, all of it.
- **"Add to current workout" appears whenever a workout is open** (any session — there is no template lock). With none open it is absent.

**Deferred screen:** Exercise history. Unreachable until sessions exist.

→ `03`.

---

## 11. Profile and History

History and Profile are both tabs (`docs/adr/0003-l0-navigation-variant-a.md`, amended by `docs/adr/0004-profile-returns-as-a-tab.md`). **The split is decided: anything computed from session rows lives on the History tab; anything the user typed lives on the Profile tab. One named exception: the Schedule pane's week summary (ADR 0004). No figure appears in both places.** → `04`, and `docs/plans/2026-09-14-2324-feat-profile-split-plan.md`.

- Stats: streak, total workouts, total sets. Streak explainer copy sits below the stat. No volume stat. **These are derived, so they live on the History tab — never on the Profile landing.**
- **Per-session PB count** — `pbCountFor(session)`. Rendered as a pill on the hero card **only when >= 1** (never "0 personal bests"). Individual PB exercises are marked in the session's exercise log below the card.
- PB requires >= 1 prior session of that exercise (no badge on first-ever occurrence) and must be **strictly** greater than the previous best. Counted per exercise, not per set.
- Compute in one chronological pass with a running per-exercise best. Not O(n^2).
- Not an achievements system. No milestones, trophies or unlockables in V1.
- History ordered by `performedOn`, `loggedAt` as tiebreaker. Rows show resolved title.
- **Session detail is the same component as the live workout card**, not a read-only viewer. Editable: title, `performedOn`, set weight/reps, add/remove set, remove exercise.
- Delete workout: session detail + history swipe. Confirm dialog. **Hard delete, no tombstone.**
- Templates: predefined are immutable; duplicate → custom copy. **Duplicate, rename, delete custom**; building one from scratch by muscle-group multi-select is deferred. **Only place templates are authored** — but the Workout tab's picker carries a visible route *to* that surface, since navigation is not authoring.
- Personal details: bodyweight and gender, both on the Profile tab because the user types them.
  - **Bodyweight is a dated series, not one number** (optional, kg, gates calories). An entry is immutable and takes effect from the day it is recorded: no edit, no delete, no backdating. A correction is a new entry that supersedes the old one going forward. One undated number plus derive-on-read would rewrite the calorie figure on every session already logged. → `04`.
  - `caloriesFor(session)` resolves the weight in effect on that session's `performedOn`. A session predating the earliest entry shows the add-weight prompt and never a figure, permanently — entering a weight later does not backfill it.
  - Gender (Male / Female / Prefer not to say, default male, selects asset pair).

→ `04`.

---

## 12. Palette

| Role | Hex |
|---|---|
| Page background | `#17140F` |
| Card / elevated surface | `#211D18` |
| Border / divider | `#332C22` |
| Muted surface / unfilled region | `#241F19` |
| Text primary | `#F5EFE8` |
| Text secondary | `#A89C8E` |
| Text muted | `#6B6156` |
| Accent strong | `#D85A30` |
| Accent light | `#F0997B` |
| Text on accent fill | `#1B0C05` |
| Destructive action | `#C4553A` |

`#D85A30` = active / trained / primary action. `#F0997B` = secondary muscle only, never a primary action. `#C4553A` = destructive action only (delete a workout, discard a session) — never a primary action, never a fill behind body text. No other colours.

⚠ `#D85A30` must not carry "delete". `01` §Usage rules gives it one meaning, *"same meaning wherever it appears"*, so a delete confirmation painted in it reads as approval. That is why the destructive colour exists; it is not a general-purpose red.

---

## 13. Out of scope for V1

No zone-lit human mascot (dead — see `mascot-brief.md`) · no per-exercise illustrations or silhouettes (V2; equipment glyphs instead) · no login · no cloud sync · no soft delete · no rest timer · no stored workout duration (the live clock is display-only, §9) · no notifications except the opt-in, fixed-schedule reminders in ADR 0005 (built after the Schedule screen) · no wearables · no AI · no premium · no ads · no multi-day splits or weekly rotation · no "today's workout" suggestion · no exercise videos · no social features.

Local storage only. Works fully offline. No onboarding wizard.

Known asset gaps, not blockers: no side-delt artwork (see §4); triceps not split by head.

---

## 14. Blocked / undecided — do not guess

**Nothing is blocked on an asset that does not exist.** All four body diagrams, the taxonomy and all 260 exercises with content are shipped and validated. (The crops are not — that system was deleted, §5.)

| Item | Status |
|---|---|
| ~~Personal bests in V1~~ | **Decided: in.** Derived, no schema cost. See `01` §Progress tracking. |
| App name | Undecided. Splash and share card use a placeholder. |
| ~~Play Store package ID~~ | **Decided:** `dev.indresh.turtle_lift` (Android) / `dev.indresh.turtleLift` (iOS). Permanent from first upload. |
