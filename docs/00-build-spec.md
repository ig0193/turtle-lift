# 00 — Build spec

**Rules only. No rationale.** Every section links to the doc that explains *why*; read that before changing a rule, not before implementing it.

| Doc | Contains |
|---|---|
| `00-build-spec.md` | This file. What to build. |
| `01-app-idea.md` | Scope, data model, muscle taxonomy, palette, and the reasoning behind every rule here. |
| `02-workout-tab-userflow.md` | Workout tab flow + mockups. |
| `03-muscle-groups-tab-userflow.md` | Muscle Groups tab flow + mockups. |
| `04-profile-tab-userflow.md` | Profile tab flow + mockups. |

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

**SessionExercise** — `exerciseId`, `order`, state ∈ `not_started | in_progress | done`.
**SetEntry** — `completed`, plus fields determined by the exercise's `loadType`:

| `loadType` | Count | Required | Optional | Set complete when | PB metric |
|---|---|---|---|---|---|
| `weighted` | 196 | `weightKg`, `reps` | — | `reps > 0` | `(weightKg, reps)` |
| `bodyweight` | 47 | `reps` | `addedKg` | `reps > 0` | `(addedKg, reps)` |
| `assisted` | 3 | `reps` | `assistKg` | `reps > 0` | `(-assistKg, reps)` ⚠ **lower is better** |
| `timed` | 14 | `durationSec` | `weightKg` | `durationSec > 0` | `(weightKg, durationSec)` |

All inputs are unsigned positive numbers; the sign is carried by the type. `assistKg` is its own field, never a negative `addedKg`. Display formats, prefill rules and the duration input spec are in `01` §Set logging by loadType.

**Exercise** (library) — `id`, `name`, `equipment`, `loadType`, `primary[]`, `secondary[]`, and four content fields rendered as separate labelled blocks on Exercise Detail, in this order:

| Field | Contains |
|---|---|
| `setup` | Equipment position and starting position. Bench angles, grip widths, foot placement, in numbers. |
| `posture` | Body alignment held throughout — chest up, ribs down, flat back, braced core. |
| `execution` | The movement, with tempo and **breathing** (inhale/exhale) on every entry. |
| `commonMistakes` | The one or two errors that matter, injury risks named plainly. |

Average 76 words per exercise across all four. Every entry mentions breathing; 198 of 260 include a specific number. **No `alternatives` field** — the sub-muscle-group exercise list serves that purpose. Source: `exercises/exercises.json`, 260 entries, validated by `validate_exercise_library.py`.

**Template** — name, `isPredefined`, and **parent muscle group ids only**. Never store sub-groups.

**No muscle-level state exists in the model.** → `01` §Muscle training state.

---

## 3. Derived values — compute on read, never store

`streak` · exercise count · set count · personal bests · **per-session PB count** · calorie estimate · `trained` ticks · resolved title.

**No lifted-volume (kg) metric anywhere in V1** — it cannot include bodyweight or timed exercises. Set count is the headline stat in its place. → `01` §Derived values.

Deleting or editing a session must change all of the above automatically, including the inline "Last time: 22kg × 10" hint. Do not introduce a stored counter. → `01` §Derived values.

---

## 4. Muscle taxonomy

Load from `muscle_taxonomy.dart`. **12 parents, 19 sub-groups, 1 mapping exception, 0 orphan segments.**

- Template rows are derived from the taxonomy at render time.
- Resolve diagram regions via the `segments` list, not by string-matching ids.
- `back/upper`, `forearms/forearms`, `calves/calves` each fill segments in **both** views. Normal.
- **`shoulders/side-delt` → `shoulders/front-delt`, FRONT VIEW ONLY.** The only exception. Never map it to `rear-delt`.
- Traps is `back/upper`, not `shoulders/*`, on both views.
- Accordion only for **chest, back, shoulders, abs**. The other 8 parents have one sub-group → render one flat row, no accordion.

→ `01` §Muscle group hierarchy.

---

## 5. Body diagram rendering

- Asset pair chosen by Profile gender field. Default male. Switching applies app-wide immediately.
- **One diagram treatment everywhere: full body, unmodified viewBox.** There is no zoomed or cropped view anywhere in V1. Used on Workout Overview, Muscle Groups landing, sub-muscle-group selection, Exercise Detail, summary and session cards.
  - **The crop system has been deleted** (`muscle_crops.json`, `muscle_crops.dart`, `generate_muscle_crops.py`). Its last two consumers — Exercise Detail and sub-muscle-group selection — both moved to full body during prototyping, because crops produced unreadable letterbox strips and lost the anatomical context that makes the diagram educational. Do not reintroduce cropping without a screen that genuinely needs it.
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
- Optional in-app hint on the final grace day. No notifications.

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

**Entry:** Start workout (template picker) · Ad-hoc workout (exercise search).

**Overview screen**
- Editable title; **no caption line**.
- Editable session date; show prominently when ≠ today.
- Muscle map heats live per completed exercise.
- Template path → nested muscle list. Ad-hoc path → flat exercise list with `not_started / in_progress / done`.
- Finish (primary) + Discard (secondary, confirm dialog).

**`trained` tick**
- Sub-group is `trained` when ≥1 completed exercise lists it as a **primary** muscle.
- Secondary muscles never tick.
- Derived, binary, read-only, gates nothing. Field name `trained`, not `done`.
- Ticked rows stay tappable; open the exercise list with logged exercises pinned to top.
- **Map and list intentionally disagree** (map = primary + secondary; list = primary only). Do not "fix".

**Template lock** — exercises outside the template's muscle groups cannot be added to a template session. Swapping within a sub-group is unrestricted.

**Finish** — available any time. **A session with 0 completed sets must not save.**

**Session persistence** — an active session persists indefinitely; never auto-discarded. Returning shows a **Resume** card. Starting a new workout auto-saves the open one (>=1 completed set, keeping its **original `performedOn`**, with a toast) or discards it silently (0 sets). One active session at a time.

**Exercise tap → set logging directly.** Info button in the logging header reaches Exercise Detail. Exception: `timesPerformed == 0` → land on Exercise Detail first.

**Set-logging screen order:** sets → Add set → Mark exercise done → Recent (last 2, all sets shown per session) → See all N sessions.

→ `02`.

---

## 10. Muscle Groups tab

- Search + browse, both landing on the shared Exercise Detail screen.
- **No logging anywhere in this tab.**
- **Exercise list** (per sub-muscle group) — vertical list of compact cards: name, equipment chip, derived `Last: 22kg × 8`. Not a horizontal carousel: this is a comparison decision ("which of these can I do right now") and it needs every option visible at once. No `alternatives` field — this list is the alternatives.
- **Exercise detail** — one screen with a per-`loadType` formatter, not four screens. Structure is identical across load types; only the tile values, recent-log rows and load-type chip change.
  - Diagram(s): **full body**. Both front and back side by side **only** when the relevant muscles span both views.
  - Three stat tiles: **Best · Last · Times**. **No "average weight"** — meaningless for `bodyweight`, `assisted` and `timed`.
  - `assisted` exercises additionally show a one-line accent banner: less assistance is better. Required — without it `Best 20kg / Last 25kg` reads as a regression.
  - **Recent log:** last 2 sessions, then **"See all N sessions"** → the dedicated **Exercise history** screen. No inline expansion, no back-to-top control (both dropped — they were workarounds for an over-long screen).
- **Exercise history screen** — one destination, reached from Exercise Detail and from set logging. Summary strip, every session newest-first with each set as a pill, PB badges on record-setting sessions, "See more" appends 20. Tapping a session opens the workout it belonged to.
  - **Empty state:** never logged → replace all three tiles and the recent list with the single line "You haven't logged this yet." Never render tiles of dashes. Diagrams, chips and how-to content still render.
- "Add to current workout" renders **only when an ad-hoc session is active**. Template session → no. No session → no.

→ `03`.

---

## 11. Profile tab

- Stats: streak, total workouts, total sets. Streak explainer copy sits below the stat. No volume stat.
- **Per-session PB count** — `pbCountFor(session)`. Rendered as a pill on the hero card **only when >= 1** (never "0 personal bests"). Individual PB exercises are marked in the session's exercise log below the card.
- PB requires >= 1 prior session of that exercise (no badge on first-ever occurrence) and must be **strictly** greater than the previous best. Counted per exercise, not per set.
- Compute in one chronological pass with a running per-exercise best. Not O(n^2).
- Not an achievements system. No milestones, trophies or unlockables in V1.
- History ordered by `performedOn`, `loggedAt` as tiebreaker. Rows show resolved title.
- **Session detail is the same component as the live workout card**, not a read-only viewer. Editable: title, `performedOn`, set weight/reps, add/remove set, remove exercise.
- Delete workout: session detail + history swipe. Confirm dialog. **Hard delete, no tombstone.**
- Templates: predefined are immutable; duplicate → editable custom copy. Create/edit/delete custom. **Only place templates are authored.**
- Personal details: bodyweight (optional, kg, gates calories) and gender (Male / Female / Prefer not to say, default male, selects asset pair).

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

`#D85A30` = active / trained / primary action. `#F0997B` = secondary muscle only, never a primary action. No other colours.

---

## 13. Out of scope for V1

No zone-lit human mascot (dead — see `mascot-brief.md`) · no per-exercise illustrations or silhouettes (V2; equipment glyphs instead) · no login · no cloud sync · no soft delete · no rest timer · no workout duration · no notifications · no wearables · no AI · no premium · no ads · no multi-day splits or weekly rotation · no "today's workout" suggestion · no exercise videos · no social features.

Local storage only. Works fully offline. No onboarding wizard.

Known asset gaps, not blockers: no side-delt artwork (see §4); triceps not split by head.

---

## 14. Blocked / undecided — do not guess

**Nothing is blocked on an asset that does not exist.** All four body diagrams, the taxonomy, the crops and all 260 exercises with content are shipped and validated.

| Item | Status |
|---|---|
| ~~Personal bests in V1~~ | **Decided: in.** Derived, no schema cost. See `01` §Progress tracking. |
| App name + **Play Store package ID** | Undecided. Package ID is permanent from first upload, including internal test tracks. |
