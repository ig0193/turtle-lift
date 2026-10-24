# Workout tab — user flow

**Purpose:** start and run a workout session — either by choosing a saved single-day workout template, or by starting empty and adding exercises as you go.

**Entry point:** Home → Workout tab.

**Important:** the app does not suggest or auto-select a workout. There is no "today's workout," no rotation logic, no AI, and no multi-day split system — every workout template is a single, self-contained day (e.g. "Push day" on its own, not day 1 of a weekly plan). The user always makes an active choice.

**The model (`docs/adr/0006-workout-tab-is-exercise-first.md`):** a session is a list of exercises. A template is a pre-filled list; an ad-hoc session is an empty one. Muscles *describe* the list (the live body map) and never *navigate* it — the Muscles tab is where you discover which exercise trains what. Visual references: `prototypes/workout-tab-options.html` (landing, session, logging) and `prototypes/workout-start-moment.html` (the start moment, variant P2). Where they differ on layout, the prototypes win; where they differ on a rule, this document wins.

---

## Step 1 — The Workout landing

**The landing is where a workout starts, with content on day one.** Eleven templates ship, so there is no empty state and no zero-data condition to design for.

### Anatomy, top to bottom

| Row | What it is |
|---|---|
| Pinned header | `Workout`. Outside the scroll body — it never moves. |
| Search field | Filters by name, across **templates and exercises**. See below. |
| `MY TEMPLATES` | The user's own templates, as a horizontal rail of tiles. **Absent entirely when they have none** — not a heading over nothing. |
| `READY-MADE` | The eleven predefined templates, as a two-column grid of tiles, in a fixed order. |
| `Manage templates` | A quiet row below the grid: the visible route to the template library on the Profile tab. Navigation, not authoring. |
| **Start workout** bar | **Pinned above the tab bar**, not scrolled with the list: `Start workout` over `Add exercises as you go`. |
| Floating tab bar | Over the content, as on every L0 root. |

The body is the scrollable and carries the gutter plus the tab bar's inset **and the pinned bar's height** itself; the header is the `Scaffold.appBar` and sits outside it.

### There is no split filter

The three-way split control (1 Muscle per day / Multi Split / Push-Pull-Legs) is gone. Its job was to keep a long list manageable, but eleven templates fit in about a screen and a half, the labels meant nothing to a new user, and with no unfiltered value the list on screen was always a subset. One flat list in a fixed order is simpler and hides nothing. **Nothing stores a "split"**, and a template belongs to no category.

### A template tile

Each tile is the template's **name**, the **muscles its exercises train** (derived from those exercises' primary muscles, in taxonomy order, sentence case: `Chest, shoulders, triceps`), and **how many exercises** it has. **Full body day** is the one exception to the derived line — it spans a dozen groups — and carries `A mix across all major groups`. A template with no exercises says `No exercises yet`.

Tapping a tile opens a **preview sheet**: the name, the muscle line, the numbered exercise list with equipment, `Start workout` and `Cancel`. Starting a template is therefore **two taps**, and the sheet is the one look at what is about to be committed to. Nothing is created until `Start workout`.

### Search

One field, **by name**, over templates and exercises:

- With the field empty, the rail and the grid show.
- Typing shows `TEMPLATES` (matching names, your own included) then `EXERCISES · TAP TO START LOGGING`. **Tapping an exercise starts an ad-hoc workout with that exercise** and goes straight to its logging screen (or its page first, if the user has never done it — Step 3).
- Nothing matching shows `Nothing matches that name.`

### Start workout

Starts an **empty** workout, in place, on the ready view (Step 2). It creates the session immediately: the ready view carries a `Discard workout` action, so a user who changes their mind is never stranded in an empty session.

### Custom templates

Created by **Save as template** on a finished workout's summary (Step 6). **Renaming, duplicating and deleting happen on the Profile tab**, never here. A custom template is the same kind of thing as a predefined one, so its tile is identical: only the `MY TEMPLATES` label sets it apart.

### What this screen deliberately does not have

- **No empty state.**
- **No Resume card, and no in-progress session UI.** An open session replaces this tab root entirely — see Step 2c.
- **No streak, no last-session recall, no body diagram, no muscle-coverage chips.**
- **No suggestion of any kind.** Nothing here states or implies a schedule, a rotation, or a recommended workout.

---

## Step 2 — Starting: the ready view

**Starting a workout must feel like starting one**, not like one list being replaced by another. So Start (from the bar, or `Start workout` in a template's preview) opens the session on a **ready view**, and the list appears only once the user taps **Start logging**:

- The pulsing "Workout in progress" strip is **not** shown yet: the workout is being set up.
- The **body map at its largest**. A template shows the muscles its exercises train as **outlines** (see the map, Step 2a).
- One line — `N exercises planned` for a template, `Nothing logged yet` for an empty start.
- One primary button: **Start logging**.
- `Discard workout` (no `Finish` — there is nothing to finish yet).

**Start logging** opens the **exercise picker** (Step 3) as a tall sheet over the map. The map stays visible behind it, so choosing an exercise reads as something done *in* the workout. Dismissing the sheet leaves the user on the **list**, not back on a button they have already pressed.

**What "started logging" is.** It is true once the user taps Start logging or opens any exercise, and it is also true whenever anything has been written to the session — so a restart mid-workout lands on the list, and a restart with nothing written lands back on the ready view. **It is held in memory only; nothing is stored for it.**

## Step 2a — The session screen

Once logging has started, the screen is, top to bottom:

1. **The live strip** — a pulsing accent dot (one pulse as it appears, not a loop), `WORKOUT IN PROGRESS`, and the **clock** on the right. See below.
2. **The date control and progress** — the session date on the left, `N of M done` on the right.
3. **The body map** — front and back, the hero of the screen. It **shrinks in steps as the list grows** (3 or fewer exercises 176pt, 4–5 152pt, 6–7 128pt, 8 or more 108pt) so the next exercise stays on screen.
4. **`KEEP LOGGING`** — the exercise list, in the order it was built, with the **first exercise that is not done tagged `UP NEXT` and outlined in the accent**.
5. `+ Add exercise`, then **Finish workout** and **Discard workout**.

- **Session date control.** The header shows the date this session will be saved under, defaulting to **today**. Tapping it opens a date picker so the user can log a workout they did earlier in the week — retrospective logging is first-class (see `01-app-idea.md`). **Clamped to today or earlier.** Applies to both paths. Stored as `performedOn`, a local calendar date. When it is anything other than today it is shown prominently (`Mon 28 Jul`) so the user can't backdate by accident and not notice.
- **Session title.** The pinned header shows an editable session title, **capped at 40 characters** — it is the hero text on a share card. **Template path:** prefilled with the template name. **Ad-hoc path:** starts **empty**; the user is never blocked on naming anything. A blank title is always resolved for display via the fallback chain in `01-app-idea.md`.
- **The list rows.** Each row is the exercise name, its logged sets (`60x10 · 60x8`), and a progress tag: `To do` / `In progress` / `Done`, **derived** from the sets and the one stored `markedDone` flag. Tapping a row opens that exercise (Step 3). Swipe or long-press removes it (asking first if it has completed sets).
- **The map.** It starts uncoloured and heats up live: **every time an exercise gets a completed set or is marked done, the muscles it trains fill in** — primary at accent-strong (`#D85A30`), secondary at accent-light (`#F0997B`). A muscle the workout *plans* to train but has not worked is **outlined** in the accent (primary muscles of every exercise on the list); an outline never sits on a filled muscle. Resolve diagram regions via the `segments` list in `muscle_taxonomy.dart`, not by string-matching.
- **There is no muscle list and no `trained` tick.** The map is the one place muscles appear on this screen.

### The clock

A live elapsed clock beside the "Workout in progress" strip, and under the exercise name on the logging screen.

- **Display-only.** It is never stored and is shown **nowhere else** — not in History, not on the summary card, not on the share card. That keeps the reason `01-app-idea.md` gives for "no workout duration" intact: retrospective logging makes a stored duration meaningless.
- It counts from when the workout started (`loggedAt`), which is within seconds of the Start logging tap, and shows `m:ss`, or `h:mm:ss` from the first hour.
- **It shows only for a workout that is happening now:** one dated the day it was started, and under **six hours** old. A backdated session never shows a clock, and one left open for days never shows a meaningless one. (Compared against the day the workout *started*, not today, so a session that crosses midnight keeps its clock.)

## Step 2c — Session persistence and resume

- **An active session persists indefinitely.** It is never auto-discarded on app close, on a date change, or after any timeout.
- Returning to the Workout tab with a session still open shows **the session itself** — it replaces the landing, so the template list and the ad-hoc entry are not on screen. There is no Resume card. The entry point for the auto-save rule below is the **list glyph in the open workout's header**, which pushes the same landing the Workout tab shows when nothing is open (search, tiles, Start workout). See `docs/adr/0003-l0-navigation-variant-a.md`.
- **Starting a new workout while one is still open auto-saves the old one** rather than discarding it or blocking the user:
  - If the abandoned session has **at least one completed set**, it is saved to history exactly as if Finish had been tapped. Show a brief toast ("Chest and triceps day saved") — work must not vanish silently into history.
  - If it has **zero completed sets**, discard it silently. Saving it would create an empty session that counts toward the streak, contradicting the rule in `01-app-idea.md`.
  - **The auto-saved session keeps its original `performedOn`**, not today's date. A Monday session abandoned and auto-saved on Wednesday must still file as Monday, or the streak is wrong.
- Only one session can be active at a time.

## Step 3 — Choosing what to log

There is one way to choose an exercise from a list, and every list ends there (`openExerciseForLogging`).

- **The exercise picker** is a tall modal sheet: a title (`What are you starting with?` the first time, `Add an exercise` after), a search field, a row of **muscle filter chips** (`All`, then the twelve parent groups), and the exercises. **The workout's own exercises come first under `IN THIS WORKOUT`**, then `ADD ANOTHER` (or `EXERCISES` when the workout is empty). Each row shows the equipment and, when the user has done it before, the last set (`Last 30kg × 10`). **Muscles are a filter, never a level to navigate down.**
- **Tapping an exercise goes straight to the set-logging screen — not to exercise detail first.** The app's promise is speed; routing every logging action through a reference screen taxes the majority who already know the lift. Exercise detail is one tap away via an **info button in the logging screen header**.
  - **One exception: if the user has never logged this exercise (`timesPerformed == 0`), land on exercise detail first**, whether it is on the list already or is being added. They cannot know a lift they have never done. A primary action there starts logging. On a fresh install every exercise in a template is new, so the first session takes this extra tap per exercise: the rule working as designed. **An exercise that already has sets written never goes back through it.**
- An exercise already in the workout **opens rather than being added twice**, which would split its sets across two prefill chains.
- **Adding is never restricted by muscle.** A template is a starting list, not a contract: the user can add any exercise to a template session, which removes the old "finish Push day with curls" workaround of two history entries for one gym visit.
- **Swap and reorder** (replace an exercise with one that trains the same muscle when a machine is taken; drag to reorder) are not built yet. The exercise's page already offers substitutes.
- **Add to current workout** on an exercise's page (reached from the Muscles tab) works in **any** open session.

## Step 4 — Log sets

- **The set row's shape depends on the exercise's `loadType`** — four variants, fully specified in `01-app-idea.md` §Set logging by loadType:
  - `weighted` (196 exercises) — `[kg] × [reps]`
  - `bodyweight` (47) — `[reps]`, plus a collapsed "add weight" chip
  - `assisted` (3) — `[kg] assist × [reps]`
  - `timed` (14) — `[m:ss]`, plus a collapsed "add weight" chip
- **Every numeric input is an unsigned positive number.** The user never types a minus sign anywhere in the app; assistance is its own field on its own load type.
- Previous session's values for the chosen exercise prefill the fields and render muted (`#6B6156`) until touched, so guessed values stay visually distinct from entered ones.
- Minimal-typing input: steppers or number pad. Duration uses quick-fill chips (`30s` `45s` `60s` `90s`); no live stopwatch in V1.
- **A set completes when the checkmark is tapped AND its required field is > 0.** Tapping the checkmark on an empty required field focuses it rather than completing the set. This is the same "completed set" that gates the streak and feeds the calorie MET tier.
- **Screen order is: sets → Add set → Mark exercise done → Recent history → See all.** The set rows are the first thing on screen; reference material sits below the actions. An earlier draft put a "Last time" line above the sets and it pushed the actual inputs down for information the ghosted prefills already convey inline.
- **Recent history shows the last 2 sessions**, each with all of that session's sets (`60x10 · 60x8 · 55x10`), followed by **"See all N sessions"**, which opens the Exercise history screen described in `03-muscle-groups-tab-userflow.md`.
- **Info button (i) in the header** opens exercise detail for form cues, without leaving the session.
- Mark set complete → mark exercise complete → return to workout overview.

## Step 5 — Repeat

- Repeat Steps 3–4 for any exercise on the list, in any order, as many or as few as the user wants. Nothing needs to be exhausted before finishing.
- The user can add exercises at any point, from any muscle.

## Step 6 — Finish workout

- Available at any time — not gated behind completing everything, and not gated behind every muscle group being ticked.
- **Discard workout** sits alongside Finish as a **secondary** button (neutral surface, not accent), so ending a session and throwing it away are visually distinct actions. Discarding requires a confirmation dialog and permanently drops the session and all its sets.
- **A session with zero completed sets must not be saved.** If the user taps Finish having logged nothing, discard silently rather than creating an empty session — an empty session would otherwise count toward the streak, contradicting the "at least one completed set" rule in `01-app-idea.md`.
- **Save as template.** Below the card — outside the part built to be screenshotted, like Delete — the summary offers **Save as template**. It asks for a name (prefilled with the workout's title) and makes a template of **the exercises that have completed sets, in the order they were done**. This is how a user's own templates are made: the workout they just did is the routine they want to repeat.
- No additional input required. Set count, exercise count, streak and calories are derived from what was already logged. There is no volume figure.
- **Personal best pill.** When the session set one or more personal bests, a pill renders directly above the stat grid: a trophy icon plus `2 personal bests` (or `1 personal best`). **It is omitted entirely when the count is zero** — never render "0 personal bests" on a card designed to be screenshotted. Definition, the first-occurrence exclusion, and the strictly-greater rule are in `01-app-idea.md` §Progress tracking.
  - It is a pill, not a fifth stat tile, precisely because most sessions won't have one and a 4-tile grid shouldn't collapse to 3 and back.
- **The session title is inline-editable on the summary card itself** — there is no separate naming step between finishing and the summary. The session saves immediately; the title is optional and can be typed, changed, or left blank. If left blank it is resolved for display via the fallback chain in `01-app-idea.md`.
- **The streak shown is `streakAsOf(session.performedOn)`, not a stored counter** — so a backdated session slots correctly into the chain rather than appearing to start a new one. Full definition and rationale in `01-app-idea.md`.
- A brief celebratory animation plays (checkmark + quick burst, similar in spirit to Strava's activity-saved moment) before landing on the workout summary screen.
- **The workout summary screen itself is designed to be screenshotted and shared** — no separate "share" button, no export step. It's the actual summary the user already lands on, just composed like something worth posting: the fully-colored muscle map front and center as the hero visual, big sets/exercises/streak numbers, minimal app chrome (just a small back/close control, no nav bar or button clutter). Someone finishing their workout can screenshot this screen exactly as it appears and post it, with zero extra taps. No workout duration is shown — see the note on retrospective logging in `01-app-idea.md`.

---

## Screen list

1. Workout tab landing (search, `MY TEMPLATES` rail, `READY-MADE` grid, pinned Start workout bar) and the template preview sheet
2. The session screen: ready view, then the live view (map, list, live strip, clock)
3. Exercise picker (sheet)
4. Exercise logging screen (sets, reps, weight)
5. Workout summary (inline-editable title; Save as template; same composition reused for Session Detail in Profile)

Note: duplicating, renaming and deleting a custom template is a separate flow that lives on the Profile tab — see that document.

## Animations specific to this tab

- **Muscle map live fill** — starts uncoloured (outlined for a plan) and animates a colour fill-in each time an exercise is logged, region by region, over the course of the session — not a one-time animation on screen load. Primary muscle = strongest fill colour, secondary = lighter fill.
- **The live strip's dot** — one pulse as it appears. **Not a loop**: a repeating animation never lets the frame scheduler settle, and a dot pulsing for the whole workout is chrome the user stops seeing within a minute.
- **Set logging confirmation** — brief, fast confirmation animation when a set is logged (not a full-screen celebration).
- **Auto-advance** — after marking an exercise complete, return to the session screen, where the next exercise is already tagged `UP NEXT`.
- **Workout saved celebration** — on finishing a workout, a brief celebratory moment plays before or as the summary screen loads: a checkmark pops in with a quick radiating burst (under ~1 second), followed by the summary stats (sets, exercises, streak) counting up. Small and fast — reinforces "you showed up" without slowing the flow or feeling like a game.
- **Screen transitions** — standard platform push/pop transitions; nothing that slows down the core loop.

## Explicitly out of scope for V1

- **No rest timer**, so no rest-timer countdown or ring.
- **No stored workout duration.** The live clock above is display-only.
- Keep the workout-saved celebration small and brief — no confetti, badges, sound effects, or full-screen takeovers.
- **Not built yet:** reorder and swap on a session row; an "Add weight" chip for bodyweight and timed exercises; quick-fill duration chips.

---

## Sample screens (Coral theme)

The landing, overview and logging mockups that used to sit here described the muscle-first design and are gone. **The references are `prototypes/workout-tab-options.html` and `prototypes/workout-start-moment.html`.** The two mockups below — the saved celebration and the shareable summary — are unchanged.

### Workout-saved celebration

Animated version — checkmark pop-in with a radiating burst, followed by stats counting up (~1.5s total, same timing breakdown as before). Note: the muscle-adjacent elements here are just checkmark/burst graphics, not a body diagram — no placeholder-vs-real distinction needed for this specific screen.

```html
<div style="background:#17140F; border-radius:16px; display:flex; flex-direction:column; align-items:center; padding:2rem 1rem 1.5rem;">
<style>
@keyframes popIn{0%{transform:scale(0);opacity:0}60%{transform:scale(1.15);opacity:1}100%{transform:scale(1)}}
@keyframes burst{0%{transform:scale(0.3) rotate(var(--r));opacity:1}100%{transform:scale(1) rotate(var(--r));opacity:0}}
@keyframes fadeUp{0%{opacity:0;transform:translateY(6px)}100%{opacity:1;transform:translateY(0)}}
.ring{position:relative;width:88px;height:88px;display:flex;align-items:center;justify-content:center}
.spark{position:absolute;top:50%;left:50%;width:3px;height:14px;margin:-7px 0 0 -1.5px;background:#D85A30;border-radius:2px;transform-origin:1.5px 44px;animation:burst 0.6s ease-out forwards;animation-delay:0.15s}
.check{width:88px;height:88px;border-radius:50%;background:#33221A;display:flex;align-items:center;justify-content:center;animation:popIn 0.5s cubic-bezier(.34,1.56,.64,1) forwards}
.stat{opacity:0;animation:fadeUp 0.4s ease-out forwards}
</style>
<div class="ring">
  <div class="spark" style="--r:0deg"></div>
  <div class="spark" style="--r:60deg"></div>
  <div class="spark" style="--r:120deg"></div>
  <div class="spark" style="--r:180deg"></div>
  <div class="spark" style="--r:240deg"></div>
  <div class="spark" style="--r:300deg"></div>
  <div class="check"><span style="font-size:36px; color:#F0997B;">&#10003;</span></div>
</div>
<p style="font-size:16px; font-weight:500; margin:1rem 0 0.25rem; color:#F5EFE8; animation:fadeUp 0.4s ease-out 0.3s forwards; opacity:0;">Workout saved</p>
<p style="font-size:13px; color:#A89C8E; margin:0 0 1.25rem; animation:fadeUp 0.4s ease-out 0.35s forwards; opacity:0;">Chest and triceps day</p>
<div style="display:grid; grid-template-columns:1fr 1fr; gap:12px; width:100%; max-width:280px;">
  <div class="stat" style="background:#211D18; border-radius:8px; padding:0.75rem; text-align:center; animation-delay:0.4s;">
    <p style="font-size:11px; color:#A89C8E; margin:0 0 2px;">Sets</p>
    <p style="font-size:18px; font-weight:500; margin:0; color:#F5EFE8;" id="dur">0</p>
  </div>
  <div class="stat" style="background:#211D18; border-radius:8px; padding:0.75rem; text-align:center; animation-delay:0.5s;">
    <p style="font-size:11px; color:#A89C8E; margin:0 0 2px;">Exercises</p>
    <p style="font-size:18px; font-weight:500; margin:0; color:#F5EFE8;" id="vol">0</p>
  </div>
  <div class="stat" style="background:#211D18; border-radius:8px; padding:0.75rem; text-align:center; animation-delay:0.6s;">
    <p style="font-size:11px; color:#A89C8E; margin:0 0 2px;">Streak</p>
    <p style="font-size:18px; font-weight:500; margin:0; color:#F5EFE8;" id="streak">0</p>
  </div>
  <div class="stat" style="background:#211D18; border-radius:8px; padding:0.75rem; text-align:center; animation-delay:0.7s;">
    <p style="font-size:11px; color:#A89C8E; margin:0 0 2px;">kcal (est.)</p>
    <p style="font-size:18px; font-weight:500; margin:0; color:#F5EFE8;" id="kcal">0</p>
  </div>
</div>
</div>
<script>
function countUp(id, end, suffix, delay){
  var el = document.getElementById(id);
  setTimeout(function(){
    var steps = 20, i = 0;
    var t = setInterval(function(){
      i++;
      var val = Math.round((end * i) / steps);
      el.textContent = val + suffix;
      if (i >= steps) { el.textContent = end + suffix; clearInterval(t); }
    }, 25);
  }, delay);
}
countUp('dur', 18, '', 450);
countUp('vol', 6480, 'kg', 550);
countUp('streak', 5, 'd', 650);
countUp('kcal', 185, '', 750);
</script>
```

**Timing summary for the Flutter implementation:**
1. `0ms` — checkmark circle begins scale/opacity pop-in (~500ms, overshoot easing so it settles with a slight bounce).
2. `150ms` — six short "spark" lines radiate outward from the circle's center and fade out (~600ms).
3. `300ms` — "Workout saved" title fades up.
4. `350ms` — the session's resolved title fades up (see the title fallback chain in `01-app-idea.md`; never rendered blank).
5. `400–700ms` — the four stat cards (sets, exercises, streak, calories) fade up in a staggered sequence, each ~100ms apart, in a 2x2 grid. If bodyweight hasn't been entered, the calories tile is replaced by the "add weight to see calories" prompt instead of animating in a stat.
6. Each stat number counts up from 0 to its final value over roughly 500ms, starting alongside its card's fade-in.
7. Total sequence length: **under 1.6 seconds** — the user should never feel like they're waiting on the animation to proceed.

### Workout summary screen (shareable by design)

The celebration animation above transitions directly into this screen — it **is** the workout summary, not a separate share screen. No share button, no export step: the mascot figure is the hero visual, stats are large and clean, and app chrome is kept to a single small back control so the screen looks intentional if screenshotted exactly as-is. This same composition is reused for Session Detail, reached from the History tab (see `04-profile-tab-userflow.md`) so past workouts are just as shareable as the moment they were saved.

Note: this mockup uses simplified placeholder body shapes; production renders `body-diagram-front.svg` / `body-diagram-back.svg` (or the female pair) exactly as the Workout Overview does. Both views appear here because chest is on the front and triceps on the back — a session confined to one view shows only that view, centred.

**The workout summary uses the standard anatomical muscle map** — the same traced SVG as every other screen, lit strong-accent for primary and light-accent for secondary. Show only the view(s) containing trained muscles, side by side when both apply, never an empty second diagram. The mascot figure originally specced here has been deferred to V2; see `01-app-idea.md`.

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:300px; overflow:hidden;">
<div style="padding:1.5rem 1.5rem 2rem; display:flex; flex-direction:column; align-items:center;">
<div style="width:100%; display:flex; justify-content:flex-start; margin-bottom:0.5rem;">
<i class="ti ti-chevron-left" style="font-size:18px; color:#A89C8E;"></i>
</div>
<p style="font-size:11px; letter-spacing:1px; color:#A89C8E; text-transform:uppercase; margin:0 0 4px;">Today</p>
<p style="font-size:20px; font-weight:600; color:#F5EFE8; margin:0 0 1.5rem; text-align:center; display:flex; align-items:center; gap:6px;">Chest and triceps day <i class="ti ti-pencil" style="font-size:13px; color:#6B6156;"></i></p>

<div style="display:flex; gap:14px; justify-content:center;">
<div style="text-align:center;">
<svg viewBox="0 0 120 190" width="88" height="139"><path d="M60 8 L74 15 L96 27 L100 74 L86 70 L84 186 L36 186 L34 70 L20 74 L24 27 L46 15 Z" fill="#241F19" stroke="#332C22" stroke-width="1.5"/><path d="M44 30 L76 30 L80 48 L40 48 Z" fill="#D85A30"/><path d="M20 28 L34 26 L34 52 L18 48 Z" fill="#F0997B"/><path d="M100 26 L86 28 L86 48 L102 52 Z" fill="#F0997B"/></svg>
<p style="font-size:10px; color:#6B6156; margin:3px 0 0;">Front</p></div>
<div style="text-align:center;">
<svg viewBox="0 0 120 190" width="88" height="139"><path d="M60 8 L74 15 L96 27 L100 74 L86 70 L84 186 L36 186 L34 70 L20 74 L24 27 L46 15 Z" fill="#241F19" stroke="#332C22" stroke-width="1.5"/><path d="M18 50 L33 53 L33 88 L17 82 Z" fill="#D85A30"/><path d="M102 53 L87 50 L87 82 L103 88 Z" fill="#D85A30"/></svg>
<p style="font-size:10px; color:#6B6156; margin:3px 0 0;">Back</p></div>
</div>

<div style="display:inline-flex; align-items:center; gap:6px; background:#33221A; border:0.5px solid #D85A30; color:#F0997B; font-size:12px; padding:5px 12px; border-radius:999px; margin-top:1rem;"><i class="ti ti-trophy" style="font-size:14px;"></i>2 personal bests</div>
<div style="display:grid; grid-template-columns:1fr 1fr; gap:16px; margin-top:1.5rem; width:100%; max-width:220px;">
<div style="text-align:center;">
<p style="font-size:22px; font-weight:600; color:#F5EFE8; margin:0;">18</p>
<p style="font-size:11px; color:#A89C8E; margin:2px 0 0;">Sets</p>
</div>
<div style="text-align:center;">
<p style="font-size:22px; font-weight:600; color:#F5EFE8; margin:0;">6</p>
<p style="font-size:11px; color:#A89C8E; margin:2px 0 0;">Exercises</p>
</div>
<div style="text-align:center;">
<p style="font-size:22px; font-weight:600; color:#D85A30; margin:0;">5</p>
<p style="font-size:11px; color:#A89C8E; margin:2px 0 0;">Day streak</p>
</div>
<div style="text-align:center;">
<p style="font-size:22px; font-weight:600; color:#F5EFE8; margin:0; display:flex; align-items:center; justify-content:center; gap:4px;">~140 <i class="ti ti-info-circle" style="font-size:12px; color:#6B6156;"></i></p>
<p style="font-size:11px; color:#A89C8E; margin:2px 0 0;">kcal (est.)</p>
</div>
</div>

<p style="font-size:10px; color:#4a4038; margin-top:1.75rem; letter-spacing:0.5px;">— APP NAME —</p>
</div>
</div>
```

Note: the personal-best pill above the stat grid renders only when the session set at least one PB. With zero, the pill is absent and the layout closes up — the card never shows a zero count.

Note on the two text lines above: the eyebrow carries the session date only (`performedOn`, rendered as Today / Yesterday / a date). The large line beneath it is the session's **resolved title** — `session.title` if the user set one, otherwise the fallback chain in `01-app-idea.md`. The two must not duplicate each other; an earlier version of this mockup repeated the muscle list in both. The title is inline-editable directly on this card (pencil affordance), which is the only naming step in the whole flow.


Note: the "Day streak" figure is computed as of this session's `performedOn` date, so it reflects the streak as it stood that day. If the user later backdates an earlier session, this number can change — that's intended, since the card stays historically accurate rather than freezing a stale value. See the workout streak definition in `01-app-idea.md`.

Note: if bodyweight hasn't been entered in Profile, the kcal tile above is replaced with a lightweight "add weight to see calories" prompt (dashed border, muted, links to Profile) rather than showing a stat — see the calorie estimate methodology and the bodyweight field in `01-app-idea.md` and `04-profile-tab-userflow.md`. Tapping the (i) icon on the kcal stat opens the same short transparency explanation.

Note: for Session Detail specifically (viewing a *past* workout from Profile), this same card sits at the top of the screen, with the full exercise-by-exercise log (sets, reps, weight) available by scrolling below it — the card handles the "shareable" job, the scrollable log below handles the "actually useful to review" job. Both live on one screen.
