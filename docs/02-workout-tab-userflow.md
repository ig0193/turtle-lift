# Workout tab — user flow

**Purpose:** start and run a workout session — either by choosing a saved single-day workout template, or by building a one-off ad-hoc session via exercise search.

**Entry point:** Home → Workout tab.

**Important:** the app does not suggest or auto-select a workout. There is no "today's workout," no rotation logic, no AI, and no multi-day split system — every workout template is a single, self-contained day (e.g. "Push day" on its own, not day 1 of a weekly plan). The user always makes an active choice.

---

## Step 1 — Choose a starting point

Two options:

1. **Start workout** — pick a workout template to run. The list shows predefined templates (Push day, Pull day, Leg day, Full body day, etc.) alongside any custom templates the user has created and saved. Creating and editing templates happens **behind the Profile avatar**, not here — this screen is only for selecting an already-saved template to start a session from.
2. **Ad-hoc workout** — search for exercises directly and add them to a session. No template or muscle-group structure required — for a user who already knows exactly what they want to do (e.g. following a YouTube trainer's routine) or wants a one-off session without saving a reusable template.
   - Adding an exercise via search just places it in the session's exercise list with a "not started" state — it does not require logging immediately.
   - Logging is a separate action, reached by tapping into any exercise in the list.
   - This means both usage patterns are supported naturally with no extra UI: a user can search → tap an exercise → land straight on the log screen for it (log-as-you-go), or search and add several exercises first, then tap into each one at their own pace (plan-ahead). There's no forced order — it's the same list and the same tap-to-log interaction either way.

Both paths converge into the same underlying session-running experience from Step 2 onward, just with different starting inputs.

## Step 2 — Workout overview

- **Session date control.** The overview header shows the date this session will be saved under, defaulting to **today**. Tapping it opens a date picker so the user can log a workout they did earlier in the week. This exists because the app explicitly supports retrospective logging (see the note on why duration isn't tracked in `01-app-idea.md`) — without an editable date, a Monday session logged on Tuesday would be filed on the wrong day and would break the user's streak with no way to fix it.
  - Defaults to today; the vast majority of sessions never touch this control.
  - **Clamped to today or earlier** — future dates are not selectable.
  - Applies to both paths, and to single-exercise quick logs.
  - Stored as `performedOn`, a local calendar date — see the session data model in `01-app-idea.md`.
  - When the date is anything other than today, show it prominently (e.g. the header reads "Mon 28 Jul" rather than a subtle chip) so the user can't backdate by accident and not notice.

- **Session title.** The overview header shows an editable session title. There is **no caption line** under the header — the title is the only text identifying the session, so nothing else needs to stay in sync with it.
  - **Template path:** prefilled with the template name (e.g. "Push day"). Without this the header would be blank and the user would lose any indication of which template they're running.
  - **Ad-hoc path:** starts **empty**. The user is never blocked on naming anything; they can leave it empty for the whole session and name it at the end, or never.
  - The title is also inline-editable on the summary card after finishing — see Step 6. A blank title is always resolved for display via the fallback chain in `01-app-idea.md`; it is never shown blank in history or on a share card.
  - Cap at **40 characters** — it is the hero text on a ~300px-wide share card.

- Both paths show a **muscle map that starts uncolored and heats up live as exercises are logged during the session** — a running visual record of what's actually been worked, not a static preview.
  - **Every time an exercise is marked complete, the muscles that exercise trains fill in on the map**: primary muscles at accent-strong (`#D85A30`), secondary muscles at accent-light (`#F0997B`). See the muscle map live fill animation below.
  - Resolve which diagram region to fill via the `segments` list in `muscle_taxonomy.dart` — not by string-matching the sub-muscle group id against the SVG. Most sub-groups map 1:1, several fill segments in both views, and side delt fills the front shoulder segment. All three cases are handled by the same lookup.
  - **Start workout (template path):** the template's sub-muscle groups appear as faint outlines from the start, so the user sees at a glance what today covers. Each outlined region heats up once an exercise training it has actually been logged, not just planned.
  - **Ad-hoc workout:** no outlines exist upfront, since there's no predefined plan. The map starts fully neutral and only gains colour as exercises are logged.

- Alongside the map, both paths show a list. **The two paths show different lists — this is intentional, not an inconsistency:**

  - **Template path — a nested muscle list.** Parent muscle groups from the template, each expanding to its sub-muscle groups (accordion). Rows are derived from `muscle_taxonomy.dart`, never stored on the template. A sub-muscle group row shows a **tick** when it has been trained this session, and shows nothing otherwise.
    - **Parents with only one sub-muscle group render as a single flat row with no accordion** — biceps, triceps, forearms, obliques, quads, hamstrings, glutes, calves. Only chest, back, shoulders and abs expand. So an Arms day is two flat rows, not two accordions each hiding one identical child.
    - **Side delt gets its own row like any other sub-muscle group**, even though it shares the front-delt diagram segment. See the side-delt mapping exception in `01-app-idea.md`; the list is driven by the taxonomy, the map by the segment mapping, and only the latter has the exception.
  - **Ad-hoc path — a flat exercise list.** The exercises the user has added, each with a per-exercise state: not started / in progress / done. There is no muscle list on this path, because there is no template to derive one from.

- **The `trained` state — precise definition.** This is the single most misread part of this screen, so it is spelled out exhaustively:
  - A sub-muscle group is `trained` when **at least one exercise whose PRIMARY muscles include it has been marked complete in this session.**
  - **Primary only. Secondary muscles never set the tick.** Incline dumbbell press is primary upper chest, secondary front delt and triceps. On a Push day it ticks upper chest and nothing else — the triceps row stays unticked, because the user has not done a triceps movement.
  - `trained` is **derived on read, never stored.** There is no muscle-level completion record in the data model. The tick is computed from the session's completed exercises and the exercise library's primary-muscle mapping, exactly like the muscle map fill and the streak. Nothing to write, nothing to reset, nothing that can drift.
  - It is **binary and read-only.** There is no "not started" state to store or render, no "in progress", and no way for the user to tick or untick a muscle directly.
  - **It gates nothing.** Finish workout is available at any point, with any number of muscles unticked. Muscle groups are a menu of options, not a checklist to complete.
  - Name the field `trained` in the model, **not `done`** — "done" implies a target the app's philosophy explicitly does not set.

- **Map and list deliberately disagree, and this must not be "fixed".** After an incline press on a Push day, triceps fills lightly on the map but its list row stays unticked. The map answers *"what got worked"* (primary and secondary). The list answers *"what have I trained directly"* (primary only). Both are correct; they answer different questions.

- **Templates are locked to their own muscle groups.** On the template path the user **cannot add an exercise outside the template's muscle groups.** A template is a fixed, coherent set of muscles the user chose to train, and keeping it sane is the point of choosing one. If the plan isn't decided, that's what the ad-hoc path is for.
  - Consequence, accepted deliberately: someone on Push day who wants to finish with barbell curls must finish that session and start an ad-hoc one, producing two history entries for one gym visit. Both count, both share the same `performedOn`, and the streak is unaffected.
  - This does **not** restrict swapping exercises — Step 3 already offers every equivalent exercise within a sub-muscle group, which covers the occupied-machine case.
  - The "Add to current workout" action in the Muscle Groups tab therefore appears **only during ad-hoc sessions**. See `03-muscle-groups-tab-userflow.md`.

## Step 2b — Session persistence and resume

- **An active session persists indefinitely.** It is never auto-discarded on app close, on a date change, or after any timeout.
- Returning to the Workout tab with a session still open shows **the session itself** — it replaces the landing, so Start workout and Ad-hoc workout are not on screen. There is no Resume card. **Note:** this removes the trigger for the auto-save rule below, which fires when a new workout is started while one is open. The rule stands; the entry point that fires it has to be restored when this screen is built. See `docs/adr/0003-l0-navigation-variant-a.md`.
- **Starting a new workout while one is still open auto-saves the old one** rather than discarding it or blocking the user:
  - If the abandoned session has **at least one completed set**, it is saved to history exactly as if Finish had been tapped. Show a brief toast ("Chest and triceps day saved") — work must not vanish silently into history.
  - If it has **zero completed sets**, discard it silently. Saving it would create an empty session that counts toward the streak, contradicting the rule in `01-app-idea.md`.
  - **The auto-saved session keeps its original `performedOn`**, not today's date. A Monday session abandoned and auto-saved on Wednesday must still file as Monday, or the streak is wrong.
- Only one session can be active at a time.

## Step 3 — Selecting what to log next

- **Template path:** user expands a parent muscle group, taps a sub-muscle group (e.g. "upper chest"), and is shown equivalent exercise options that train it (e.g. incline barbell press, incline dumbbell press, incline machine press). This lets the user switch exercises on the fly if a machine is occupied.
  - **Tapping an exercise goes straight to the set-logging screen — not to exercise detail first.** The app's promise is speed; routing every logging action through a reference screen taxes the majority who already know the lift. Exercise detail is one tap away via an **info button in the logging screen header**.
    - **One exception: if the user has never logged this exercise (`timesPerformed == 0`), land on exercise detail first.** They cannot know a lift they have never done, and this targets exactly that case using data already available. From there a primary action starts logging.
  - **A ticked sub-muscle group remains tappable**, and opens the same exercise list with any exercise already logged this session pinned to the top, showing its logged sets. This is the only route back in to add a fourth set or correct a mistyped weight, so it must not be disabled once the tick appears.
- **Ad-hoc path:** user taps an already-added exercise in the list to log it, or searches to add another exercise to the list at any point — before or after logging others. Adding and logging are independent actions using the same list.

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

- Repeat Steps 3–4 for any sub-muscle group (template path) or added exercise (ad-hoc path), in any order, as many or as few as the user wants. Nothing needs to be exhausted before finishing.
- For the ad-hoc path, the user can keep adding new exercises mid-session via search at any point. On the template path, exercises outside the template's muscle groups cannot be added — see Step 2.

## Step 6 — Finish workout

- Available at any time — not gated behind completing everything, and not gated behind every muscle group being ticked.
- **Discard workout** sits alongside Finish as a **secondary** button (neutral surface, not accent), so ending a session and throwing it away are visually distinct actions. Discarding requires a confirmation dialog and permanently drops the session and all its sets.
- **A session with zero completed sets must not be saved.** If the user taps Finish having logged nothing, discard silently rather than creating an empty session — an empty session would otherwise count toward the streak, contradicting the "at least one completed set" rule in `01-app-idea.md`.
- No additional input required. Set count, exercise count, streak and calories are derived from what was already logged. There is no volume figure.
- **Personal best pill.** When the session set one or more personal bests, a pill renders directly above the stat grid: a trophy icon plus `2 personal bests` (or `1 personal best`). **It is omitted entirely when the count is zero** — never render "0 personal bests" on a card designed to be screenshotted. Definition, the first-occurrence exclusion, and the strictly-greater rule are in `01-app-idea.md` §Progress tracking.
  - It is a pill, not a fifth stat tile, precisely because most sessions won't have one and a 4-tile grid shouldn't collapse to 3 and back.
- **The session title is inline-editable on the summary card itself** — there is no separate naming step between finishing and the summary. The session saves immediately; the title is optional and can be typed, changed, or left blank. If left blank it is resolved for display via the fallback chain in `01-app-idea.md`.
- **The streak shown is `streakAsOf(session.performedOn)`, not a stored counter** — so a backdated session slots correctly into the chain rather than appearing to start a new one. Full definition and rationale in `01-app-idea.md`.
- A brief celebratory animation plays (checkmark + quick burst, similar in spirit to Strava's activity-saved moment) before landing on the workout summary screen.
- **The workout summary screen itself is designed to be screenshotted and shared** — no separate "share" button, no export step. It's the actual summary the user already lands on, just composed like something worth posting: the fully-colored muscle map front and center as the hero visual, big sets/exercises/streak numbers, minimal app chrome (just a small back/close control, no nav bar or button clutter). Someone finishing their workout can screenshot this screen exactly as it appears and post it, with zero extra taps. No workout duration is shown — see the note on retrospective logging in `01-app-idea.md`.

---

## Screen list

1. Workout tab landing (two entry options: Start workout / Ad-hoc workout)
2. Workout template picker (list of predefined + custom saved templates, for Start workout)
3. Exercise search + add (for Ad-hoc workout)
4. Workout overview (muscle map + nested muscle list on the template path, or flat exercise list on the ad-hoc path; editable title; editable session date; Finish and Discard)
5. Sub-muscle group → exercise options (template path; reachable whether or not the sub-muscle group is already ticked)
6. Exercise logging screen (sets, reps, weight)
7. Workout summary (inline-editable title; same composition reused for Session Detail in Profile)

Note: creating/editing a custom workout template is a separate flow that lives behind the Profile avatar — see that document.

## Animations specific to this tab

- **Muscle map live fill** — the workout overview's muscle map starts uncolored (or, for the template path, shows faint target outlines) and animates a color fill-in each time an exercise is logged, region by region, over the course of the session — not a one-time animation on screen load. Primary muscle = strongest fill color, secondary = lighter fill, not-yet-logged = neutral/outline. This makes the map function as a live progress record of the session, reusable as-is between the template and ad-hoc paths.
- **Parent muscle group expand/collapse** — smooth accordion animation when expanding a template's parent muscle group to reveal its sub-muscle groups. Template path only; the ad-hoc path has a flat exercise list with nothing to expand. Parents with a single sub-muscle group have no accordion and no animation — they are a plain tappable row.
- **Progress indicator** — when an exercise is marked complete, the tick on each of its **primary** sub-muscle groups animates in (scale/fade). Secondary muscles never tick. On the ad-hoc path the same animation applies to the exercise row's own done state.
- **Set logging confirmation** — brief, fast confirmation animation when a set is logged (not a full-screen celebration).
- **Auto-advance** — after marking an exercise complete, smoothly transition back to workout overview, ideally highlighting or scrolling to the next incomplete item.
- **Workout saved celebration** — on finishing a workout, a brief celebratory moment plays before or as the summary screen loads: a checkmark pops in with a quick radiating burst (under ~1 second), followed by the summary stats (sets, exercises, streak) counting up. Small and fast, closer to Strava's activity-saved moment than a full celebration screen — reinforces "you showed up" without slowing down the flow or feeling like a game.
- **Screen transitions** — standard platform push/pop transitions; nothing that slows down the core loop.

## Explicitly out of scope for V1

- No rest timer, so no rest timer countdown/ring animation.
- Keep the workout-saved celebration small and brief — no confetti, badges, sound effects, or full-screen takeovers.

---

## Sample screens (Coral theme)

Reference HTML/CSS mockups for this tab's key screens, using the Coral palette defined in `01-app-idea.md`. These are visual/layout references for Claude Code to translate into Flutter, not production code.

### Workout tab landing

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 0.5rem;">
<h1 style="margin:0.5rem 0 1.25rem; color:#F5EFE8;">Workout</h1>
<button style="width:100%; text-align:left; padding:1rem; margin-bottom:12px; display:flex; align-items:center; gap:12px; background:#211D18; border:0.5px solid #332C22; border-radius:8px; color:#F5EFE8;">
<i class="ti ti-list" style="font-size:22px; color:#A89C8E;"></i>
<div><p style="margin:0; font-weight:500; font-size:15px;">Start workout</p><p style="margin:0; font-size:13px; color:#A89C8E;">Pick a saved template</p></div>
</button>
<button style="width:100%; text-align:left; padding:1rem; display:flex; align-items:center; gap:12px; background:#211D18; border:0.5px solid #332C22; border-radius:8px; color:#F5EFE8;">
<i class="ti ti-search" style="font-size:22px; color:#A89C8E;"></i>
<div><p style="margin:0; font-weight:500; font-size:15px;">Ad-hoc workout</p><p style="margin:0; font-size:13px; color:#A89C8E;">Search and add exercises</p></div>
</button>
</div>
<div style="display:flex; border-top:0.5px solid #332C22; margin-top:1.5rem;">
<div style="flex:1; text-align:center; padding:10px 0; color:#D85A30;"><i class="ti ti-barbell" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Workout</p></div>
<div style="flex:1; text-align:center; padding:10px 0; color:#6B6156;"><i class="ti ti-stretching" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Muscles</p></div>
<div style="flex:1; text-align:center; padding:10px 0; color:#6B6156;"><i class="ti ti-user" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Profile</p></div>
</div>
</div>
```

### Workout overview (live muscle map + progress list)

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 0.5rem;">
<div style="display:flex; align-items:center; gap:8px; margin-bottom:0.75rem;">
<i class="ti ti-arrow-left" style="font-size:18px; color:#A89C8E;"></i>
<h2 style="margin:0; color:#F5EFE8;">Chest and triceps day</h2>
<i class="ti ti-pencil" style="font-size:14px; color:#6B6156;"></i>
</div>
<button style="display:flex; align-items:center; gap:6px; background:#211D18; border:0.5px solid #332C22; border-radius:8px; padding:6px 10px; color:#A89C8E; font-size:12px; margin-bottom:0.5rem;">
<i class="ti ti-calendar" style="font-size:14px;"></i>Today<i class="ti ti-chevron-down" style="font-size:12px; color:#6B6156;"></i>
</button>
<div style="display:flex; justify-content:center; margin:0.5rem 0 1rem;">
<svg viewBox="0 0 200 260" width="140" height="182">
<circle cx="100" cy="22" r="14" fill="#3a2f26"/>
<ellipse cx="70" cy="52" rx="14" ry="9" fill="#D85A30"/>
<ellipse cx="130" cy="52" rx="14" ry="9" fill="#D85A30"/>
<rect x="80" y="46" width="40" height="28" rx="7" fill="#D85A30"/>
<rect x="48" y="60" width="13" height="42" rx="6" fill="none" stroke="#3d332a" stroke-width="2"/>
<rect x="139" y="60" width="13" height="42" rx="6" fill="none" stroke="#3d332a" stroke-width="2"/>
<rect x="50" y="64" width="5" height="34" rx="2.5" fill="#F0997B"/>
<rect x="145" y="64" width="5" height="34" rx="2.5" fill="#F0997B"/>
<rect x="82" y="78" width="36" height="38" rx="6" fill="#241f19"/>
<rect x="78" y="118" width="18" height="66" rx="8" fill="#241f19"/>
<rect x="104" y="118" width="18" height="66" rx="8" fill="#241f19"/>
</svg>
</div>
<div style="border-top:0.5px solid #332C22; margin-top:0.5rem;">
<div style="display:flex; align-items:center; justify-content:space-between; padding:0.75rem 0; border-bottom:0.5px solid #332C22;">
<span style="font-size:14px; color:#F5EFE8;">Upper chest</span>
<i class="ti ti-check" style="font-size:18px; color:#D85A30;"></i>
</div>
<div style="display:flex; align-items:center; justify-content:space-between; padding:0.75rem 0; border-bottom:0.5px solid #332C22;">
<span style="font-size:14px; color:#F5EFE8;">Mid chest</span>
<i class="ti ti-check" style="font-size:18px; color:#D85A30;"></i>
</div>
<div style="display:flex; align-items:center; justify-content:space-between; padding:0.75rem 0; border-bottom:0.5px solid #332C22;">
<span style="font-size:14px; color:#F5EFE8;">Lower chest</span>
<i class="ti ti-chevron-right" style="font-size:16px; color:#6B6156;"></i>
</div>
<div style="display:flex; align-items:center; justify-content:space-between; padding:0.75rem 0;">
<span style="font-size:14px; color:#F5EFE8;">Triceps</span>
<i class="ti ti-chevron-right" style="font-size:16px; color:#6B6156;"></i>
</div>
</div>
<button style="width:100%; margin:1rem 0 8px; background:#D85A30; color:#1B0C05; border:none; padding:10px; border-radius:8px; font-size:14px; font-weight:500;">Finish workout</button>
<button style="width:100%; margin-bottom:0.5rem; background:#211D18; border:0.5px solid #332C22; color:#A89C8E; padding:10px; border-radius:8px; font-size:14px;">Discard workout</button>
</div>
</div>
```

Notes on this mockup:
- **The template shown is "Chest and triceps day", not "Push day".** Push day is chest + shoulders + triceps, which expands to seven sub-muscle group rows, not four. Chest and triceps day is also a predefined template, and four rows is correct for it.
- **There is no caption line** — the editable title is the only identifying text on this screen.
- **Ticks mark trained sub-muscle groups; untrained rows show a chevron, not a "Not started" label.** There is no stored not-started state.
- The muscle map here is a static snapshot for reference — in the real app it starts unfilled/outlined and heats each region in live as the corresponding exercise is logged (see the muscle map live fill animation below). It is also simplified to one shape per major muscle group for this mockup; the real diagram needs a distinct segment per sub-muscle group — see "Body diagram requirement" in `01-app-idea.md`.
- The parent-group accordion is collapsed out of this mockup for brevity; in the real screen "Chest" expands to its three bands.

### Exercise logging screen

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 0.5rem;">
<div style="display:flex; align-items:center; gap:8px; margin-bottom:4px;">
<i class="ti ti-arrow-left" style="font-size:18px; color:#A89C8E;"></i>
<h2 style="margin:0; color:#F5EFE8;">Incline dumbbell press</h2>
</div>
<p style="font-size:12px; color:#A89C8E; margin:0 0 1rem;">Last time: 22kg &times; 10, 22kg &times; 9, 20kg &times; 10</p>
<div style="border-top:0.5px solid #332C22;">
<div style="display:grid; grid-template-columns:1fr 2fr 2fr 1fr; gap:8px; padding:0.5rem 0; font-size:11px; color:#6B6156;">
<span>Set</span><span>Weight</span><span>Reps</span><span></span>
</div>
<div style="display:grid; grid-template-columns:1fr 2fr 2fr 1fr; gap:8px; align-items:center; padding:0.5rem 0; border-top:0.5px solid #332C22;">
<span style="font-size:14px; color:#F5EFE8;">1</span>
<input type="text" value="22 kg" style="width:100%; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:6px; padding:6px;" />
<input type="text" value="10" style="width:100%; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:6px; padding:6px;" />
<i class="ti ti-check" style="font-size:18px; color:#D85A30; justify-self:center;"></i>
</div>
<div style="display:grid; grid-template-columns:1fr 2fr 2fr 1fr; gap:8px; align-items:center; padding:0.5rem 0; border-top:0.5px solid #332C22;">
<span style="font-size:14px; color:#F5EFE8;">2</span>
<input type="text" value="22 kg" style="width:100%; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:6px; padding:6px;" />
<input type="text" value="9" style="width:100%; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:6px; padding:6px;" />
<i class="ti ti-check" style="font-size:18px; color:#D85A30; justify-self:center;"></i>
</div>
</div>
<button style="width:100%; margin-top:0.75rem; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:8px; padding:8px; display:flex; align-items:center; justify-content:center; gap:6px;">
<i class="ti ti-plus" style="font-size:16px;"></i>Add set</button>
<button style="width:100%; margin-top:1.25rem; background:#D85A30; color:#1B0C05; border:none; border-radius:8px; padding:10px; font-size:14px; font-weight:500;">Mark exercise complete</button>
</div>
</div>
```

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
