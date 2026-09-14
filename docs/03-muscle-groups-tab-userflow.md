# Muscle Groups tab — user flow

**Purpose:** exploration and reference. For a user who doesn't want to build a full workout and just wants to find or understand a specific exercise. This is the app's "MuscleWiki" experience — no logging happens here.

**Entry point:** Home → Muscles tab.

---

## What ships, and what is deferred

The tab ships as **pure reference**: browse by body map or by list, search across exercises, muscles and equipment, and read the reviewed how-to content for any of the 260 exercises. Nothing in it reads or writes a user's training history.

**Every personal figure this document describes is deferred to a later plan, not dropped.** The `Session` / `SessionExercise` / `SetEntry` tables do not exist yet, and there is no set-logging screen — so a user could not produce that history even if the tables did exist, and every derived surface would render an empty state on device. The rules stay written down, marked **Deferred**, because they are what that plan builds against:

- the map's trained/untrained fill;
- the derived `Last: 22kg × 8` line on exercise-list rows;
- the Best / Last / Times tiles, the recent log and the personal-best badges;
- the Exercise history screen;
- the `assisted` inverted-record banner;
- the "You haven't logged this yet" empty state;
- "Add to current workout".

**Two screens this document used to specify were deleted rather than deferred** — see "Two screens were deleted, not deferred" under Screen list.

## Three routes into the same destination

1. **Search** — the field at the top of the landing opens a search screen over **three vocabularies**: the 260 exercise names, the 19 sub-muscle group labels, and the 8 equipment values. Every result states which kind it is, because the words overlap — "kettlebell" is an equipment value *and* the first word of twelve exercise names. Each kind routes to its own destination: an exercise to its detail screen, a muscle to that sub-muscle group's exercise list, an equipment value to a list of every exercise using it. A query matching no exercise name still shows the full muscle list and the full equipment list rather than an empty screen.
2. **The body map** — tap a segment and land **directly** on that sub-muscle group's exercise list. Nothing sits in between.
3. **The sub-group list** — all 19 sub-muscle groups as one flat list beneath the map, ordered by parent group, each row carrying how many exercises name it as a *primary* muscle. It reaches the same exercise list a segment tap reaches, and it is the **only** route to `shoulders/side-delt`, which has no artwork of its own — that row says so, so a user who went hunting for it on the diagram learns why rather than concluding the app is missing a muscle.

The map and the list share the landing deliberately. The map answers "what is this bit of me called"; the list answers "where are my lats in this app" without a game of hunt-the-polygon. Either alone would strand one of the two ways people arrive here.

All three routes land on the same exercise detail screen — this screen is shared across the entire app (also reached from within a workout session).

## Exercise detail screen

Shown regardless of entry path (search, browse, or from inside a workout). What ships, in render order:

- **Equipment and load type**, as one line under the header.
- **Primary and secondary muscles**, as labelled chips above the diagram(s).
- **Muscle diagram — FULL BODY, not a zoomed crop.** Primary muscles fill at accent-strong, secondary at accent-light, everything else stays neutral. The diagram here is **read-only** — there is nowhere for a tap to go, since the reader is already looking at the answer it would navigate to.
  - **This reverses an earlier decision.** Exercise detail originally specced a zoomed crop from `muscle_crops.dart`. In the prototype that failed visibly: lower chest crops to a 459x69 letterbox strip that reads as a rendering bug, and at 118px wide the zoomed muscle was no more legible than the full figure. Full body also does the educational job better, since the user sees *where* the muscle sits rather than an isolated shape.
  - **If the relevant muscles span both views, both diagrams render side by side**, each full body. If one view covers everything, only that one shows, centred. **Secondary muscles count towards that choice, not only primaries** — incline dumbbell press has chest and front delts on the front but triceps only on the back, so it takes both. 55 of the 260 exercises are covered by the back view alone, so a page fixed to the front would render a complete, plausible body with the one muscle it exists to show left grey.
  - **The crop system has been deleted.** Exercise detail was its last remaining consumer once sub-muscle-group selection was deleted as a screen; nothing renders a cropped or zoomed viewBox anywhere in V1. → `00` §5.
- **The four reviewed content fields as collapsible rows** — **Common mistakes first and expanded**, then Setup, Posture and Execution, collapsed. Common mistakes leads and opens because it is the field carrying the injury risk. All four render **verbatim**: reviewed copy, never rewritten, summarised, regenerated, truncated or reflowed.
- **A rail of substitutes** — other exercises sharing **any** of this one's primary sub-muscle groups, different equipment ordered first, capped at 8. 31 of the 260 exercises carry two primary sub-groups, so requiring the full set to match would empty the rail for them. The rail is titled after the muscle when the exercise has exactly one primary and neutrally when it has more: naming only the first would mislabel every card that matched the second.

**The page offers no way into a workout.** Logging is the Workout tab's job, and there is no session to add anything to — see "Visiting mid-workout".

### Personal history — deferred

**None of this is on the shipped page.** No stat tiles, no recent list, no personal-best badge, and no line standing in for them — not even "You haven't logged this yet", which is a claim about the reader that a reference page has no business making when the app provides no way to log. A user with zero sessions sees exactly what a user with three hundred sees. The rules below are what the later plan builds.

- **Personal history — three stat tiles: Best, Last, Times.**
  - **Average weight has been removed from the spec.** It is meaningless for three of the four load types — there is no average weight for a plank or a push-up. `Last` replaces it and is more actionable anyway: the last session is what the user is trying to beat, an average is trivia.
  - All three tiles are formatted by the exercise's `loadType` using the single display formatter in `01-app-idea.md` §Set logging by loadType. `Best` uses that type's PB metric.

    | `loadType` | Best | Last | Times |
    |---|---|---|---|
    | `weighted` | `26kg × 8` | `22kg × 10` | `14` |
    | `bodyweight` | `+5kg × 6` | `9 reps` | `21` |
    | `assisted` | `20kg × 8` | `25kg × 8` | `6` |
    | `timed` | `1:30` | `1:00` | `9` |

  - **`assisted` exercises show an explanatory banner above the tiles** — accent-bordered, one line: "Less assistance is better. Your record is the lightest assist you've used." Without it, `Best 20kg / Last 25kg` reads as a regression. This is the only inverted metric in the app and the only screen carrying an explanatory banner; if a second one ever becomes necessary, that is a signal the inversion shouldn't be user-facing at all.
- **The screen's structure is identical across all four load types** — only the three tile values, the recent-log rows and the load-type chip change. Build one screen with a formatter, not four screens.

### Recent log — last 2, then a dedicated screen — deferred

- Exercise detail shows the **last 2 sessions**, then a **"See all N sessions"** button.
- **That button navigates to a dedicated Exercise history screen — it does NOT expand inline.** This replaces the earlier "See more appends 5 per tap, page scrolls, back-to-top control appears" design. Expanding in place made an already-long detail screen much longer, and the back-to-top control existed only to paper over that. A list screen scrolls naturally and needs neither.
- The same Exercise history screen is also the destination for the **"See all N sessions"** link on the set-logging screen. One destination, one component, reached from two places.

### Exercise history screen — deferred

Not built. Full record for a single exercise, reached from exercise detail and from the set-logging screen — neither of which can offer it until sessions exist.

- Header: exercise name.
- Summary strip: total sessions, best, date first logged.
- **Every session, newest first**: date plus a relative date ("1 Jul · 2 weeks ago"), and each set rendered as its own pill using the standard `loadType` formatter. Showing sets individually matters — `60x10 · 60x8 · 55x10` reveals the drop-off across a session, which a single "last: 60kg x 8" hides.
- **Sessions that set a personal best carry a PB badge**, with the record-setting set highlighted in accent. Same `pbCountFor` derivation as the workout summary card. This screen is the only place the whole progression arc is visible, so marking where the records happened is what turns a log into a story.
- Paging: **"See more" appends 20 sessions per tap.** No infinite scroll.
- **Tapping a session opens the full workout it belonged to** (Session Detail in Profile), so the user can see what else they did that day.
- No empty state needed — this screen is unreachable with no history.

### Empty state — never logged — deferred

- When the user has never logged this exercise, **replace the entire history block** — all three tiles and the recent list — with a single muted line: "You haven't logged this yet."
- Do **not** render three tiles of dashes. An empty grid reads as broken; one line reads as a state.
- The diagrams, muscle legend, equipment chips and the how-to content all still render. Reference value does not depend on history.

**This tab does not log sets.** It's a pure explore/reference surface — no "log this exercise" action lives here. All logging happens in the Workout tab.

## Visiting mid-workout

- The user can freely visit the Muscle Groups tab while a workout session is active — for example, to check an alternative exercise's form cues or muscles worked before deciding what to do next. This doesn't disrupt or pause the active session.

**"Add to current workout" is deferred.** No session exists yet, so today the exercise detail screen shows the reference content and nothing else, in every case. The rules below are what the later plan builds.

- **When an AD-HOC session is active**, the exercise detail screen shows one additional contextual action: **Add to current workout** — this adds the exercise to the active session's exercise list as not-started, the same as if it had been found via search from inside the Workout tab. It does not log sets from here; the user logs it back in the active workout flow, consistent with logging always happening in one place.
- **When a TEMPLATE-based session is active, this action does not appear.** Template sessions are locked to their own muscle groups — an exercise outside the template cannot be added to it. See "Templates are locked to their own muscle groups" in `02-workout-tab-userflow.md` for the rationale. During a template session this tab stays pure reference, exactly as it is with no session active.
- When no session is active, the exercise detail screen shows no action beyond the reference content — there's nothing to add it to yet.
- **Summary of when the button renders:** ad-hoc session active → yes. Template session active → no. No session → no.

---

## Screen list

Four screens ship:

1. **Muscle Groups tab landing** — search field, front/back view control, the full-body map with **every segment muted**, and all 19 sub-group rows with their primary-exercise counts. No fill on the map stands for training; that colour is deferred, and the diagram takes its fill as a caller-supplied parameter so adding it later does not reopen the screen.
2. **Search** — one field over the three vocabularies, every result labelled by kind, routing by kind. Never an empty result screen.
3. **Exercise list** (for one sub-muscle group) — vertical list of compact rows: name and equipment chip. The derived `Last: 22kg × 8` line is deferred.
4. **Exercise detail** (shared screen — equipment and load type, muscle chips, full-body diagram(s), the four content fields as collapsible rows, substitutes rail). No history block; no "Add to current workout".

**The equipment-filtered exercise list is a search destination, not a browse screen.** Nothing navigates to it except an equipment search result, so it gets no entry of its own above. It is the sub-group list's sibling — same screen shape, same rows, same destination for a tap — differing only in which query fills it.

**Deferred screen:** Exercise history (full record for one exercise; PB badges; reached from exercise detail and from set logging). It has no reachable entry point until sessions exist.

### Two screens were deleted, not deferred

"Muscle group selection" and "Sub-muscle group selection" — a parent-then-child picker sitting between the body map and the exercise list — **are not built, and are not coming back.**

- **This document contradicted itself about them.** The landing mockup note below already required a segment tap to go "directly into that sub-muscle group's exercise list, not into a generic parent-muscle view first". The taxonomy settles which side was right.
- **Of 42 segments, exactly one is ambiguous.** `shoulders/front-delt` also carries `shoulders/side-delt`, because side delt has no artwork of its own. The other 41 resolve to a single sub-muscle group. A two-screen picker for all 42 would have asked the user, 41 times out of 42, to re-state something they had already said by tapping.
- **That one segment asks, and only that one.** Tapping the front delt opens a two-option bottom sheet — Front delt or Side delt — and pushes whichever is chosen. Dismissing it opens nothing: a tap on a small polygon lands on the wrong one often enough that backing out has to be free. Which segment is ambiguous is read from the taxonomy at runtime, never hard-coded, so a regenerated taxonomy moves the question with it.
- **Side delt is still reachable** — through the sub-group list, which is its only route (see "Three routes").

## Animations specific to this tab

- **Muscle map highlight** — one reusable full-body component used on every screen. Interactive on the landing, read-only on exercise detail. No cropped or zoomed variant exists.
- **No accordion in this tab.** The 4-expand / 8-flat rule is a **Workout tab** rule — it governs the template path's nested muscle list (`02-workout-tab-userflow.md`, `00` §4). The screens that used it here were deleted. Exercise detail's four content fields are disclosure rows, not that accordion: each opens independently, and Common mistakes starts open.
- **Search-to-result transition** — fast, minimal-motion transition from typing a query to landing on exercise detail, since speed is the main value of search over browsing.
- **Add-to-workout confirmation — deferred**, with the action it confirms. When an ad-hoc session is active and the user taps "Add to current workout," a brief, lightweight confirmation (e.g. a small toast or button state change) confirms the exercise was added to the session — not a full logging interaction, since no sets are entered here.

## Explicitly out of scope for V1

- No rest timer.
- No celebratory full-screen animations.

---

## Sample screens (Coral theme)

Reference HTML/CSS mockups for this tab's key screens, using the Coral palette defined in `01-app-idea.md`.

### Muscle Groups tab landing

Note: this mockup uses one shape per major muscle group for simplicity, and predates the shipped landing — it shows neither the front/back control nor the list of 19 sub-group rows beneath the map. The real body diagram has a distinct, individually tappable segment per sub-muscle group (e.g. upper/mid/lower chest as three separate regions) — see "Body diagram requirement" in `01-app-idea.md`. Tapping a specific segment goes directly into that sub-muscle group's exercise list, not into a generic parent-muscle view first; that is what ships, and it is why the two selection screens were deleted.

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 0.5rem;">
<h1 style="margin:0.5rem 0 1rem; color:#F5EFE8;">Muscle groups</h1>
<div style="position:relative; margin-bottom:1.25rem;">
<i class="ti ti-search" style="position:absolute; left:10px; top:50%; transform:translateY(-50%); font-size:16px; color:#6B6156;"></i>
<input type="text" placeholder="Search exercises" style="width:100%; padding:8px 8px 8px 32px; background:#211D18; border:0.5px solid #332C22; border-radius:8px; color:#F5EFE8;" />
</div>
<div style="display:flex; justify-content:center;">
<svg viewBox="0 0 200 300" width="160" height="240">
<circle cx="100" cy="24" r="15" fill="#3a2f26"/>
<ellipse cx="68" cy="56" rx="15" ry="10" fill="#F0997B"/>
<ellipse cx="132" cy="56" rx="15" ry="10" fill="#F0997B"/>
<rect x="78" y="50" width="44" height="30" rx="7" fill="#F0997B"/>
<rect x="44" y="66" width="14" height="46" rx="6" fill="#D85A30" opacity="0.4"/>
<rect x="142" y="66" width="14" height="46" rx="6" fill="#D85A30" opacity="0.4"/>
<rect x="42" y="116" width="13" height="40" rx="6" fill="#241f19"/>
<rect x="145" y="116" width="13" height="40" rx="6" fill="#241f19"/>
<rect x="80" y="84" width="40" height="42" rx="6" fill="#D85A30" opacity="0.55"/>
<rect x="76" y="130" width="20" height="76" rx="8" fill="#241f19"/>
<rect x="104" y="130" width="20" height="76" rx="8" fill="#241f19"/>
</svg>
</div>
<p style="text-align:center; font-size:12px; color:#A89C8E; margin:0.5rem 0 0;">Tap a muscle to explore exercises</p>
</div>
<div style="display:flex; border-top:0.5px solid #332C22; margin-top:1.25rem;">
<div style="flex:1; text-align:center; padding:10px 0; color:#6B6156;"><i class="ti ti-barbell" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Workout</p></div>
<div style="flex:1; text-align:center; padding:10px 0; color:#D85A30;"><i class="ti ti-stretching" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Muscles</p></div>
<div style="flex:1; text-align:center; padding:10px 0; color:#6B6156;"><i class="ti ti-user" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Profile</p></div>
</div>
</div>
```

### Exercise detail

Note: this mockup uses simplified placeholder shapes for both diagrams. Production uses the four traced body diagrams — the pair chosen by the Profile gender field — **full body, at their own unmodified viewBox. Never cropped, never zoomed**: the crop system has been deleted and must not be rebuilt (`00` §5). This example does demonstrate the front+back decision: incline dumbbell press has chest and front delts (front view) as primary/secondary, but triceps (secondary) only exists on the back view — so both diagrams are needed here, side by side.

The mockup also predates the shipped screen below the diagrams: the Best/Last/Times tiles, the "Recent" rows, "See more" and "Add to current workout" are all **deferred** and render nowhere today. What ships in their place is the four reviewed content fields as collapsible rows, then the substitutes rail.

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 0.5rem;">
<div style="display:flex; align-items:center; gap:8px; margin-bottom:8px;">
<i class="ti ti-arrow-left" style="font-size:18px; color:#A89C8E;"></i>
<h2 style="margin:0; color:#F5EFE8;">Incline dumbbell press</h2>
</div>
<div style="display:flex; justify-content:center; gap:16px; margin:0.5rem 0;">
<div style="text-align:center;">
<svg viewBox="0 0 200 260" width="90" height="117">
<circle cx="100" cy="22" r="14" fill="#3a2f26"/>
<ellipse cx="70" cy="52" rx="14" ry="9" fill="#D85A30"/>
<ellipse cx="130" cy="52" rx="14" ry="9" fill="#D85A30"/>
<rect x="80" y="46" width="40" height="28" rx="7" fill="#D85A30"/>
<rect x="82" y="78" width="36" height="38" rx="6" fill="#241f19"/>
</svg>
<p style="font-size:10px; color:#6B6156; margin:4px 0 0;">Front</p>
</div>
<div style="text-align:center;">
<svg viewBox="0 0 200 260" width="90" height="117">
<circle cx="100" cy="22" r="14" fill="#3a2f26"/>
<rect x="80" y="46" width="40" height="28" rx="7" fill="#241f19"/>
<rect x="48" y="60" width="13" height="42" rx="6" fill="#F0997B"/>
<rect x="139" y="60" width="13" height="42" rx="6" fill="#F0997B"/>
</svg>
<p style="font-size:10px; color:#6B6156; margin:4px 0 0;">Back</p>
</div>
</div>
<div style="font-size:12px; color:#A89C8E; margin-bottom:4px;"><i class="ti ti-square-filled" style="font-size:9px; color:#D85A30;"></i> Primary: upper chest</div>
<div style="font-size:12px; color:#A89C8E; margin-bottom:1rem;"><i class="ti ti-square-filled" style="font-size:9px; color:#F0997B;"></i> Secondary: front delts, triceps</div>
<div style="background:#211D18; border-radius:8px; padding:0.75rem; margin-bottom:1rem;">
<p style="font-size:11px; color:#A89C8E; margin:0 0 4px;">Equipment</p>
<p style="font-size:13px; color:#F5EFE8; margin:0 0 8px;">Dumbbells, incline bench</p>
<p style="font-size:11px; color:#A89C8E; margin:0 0 4px;">Form cue</p>
<p style="font-size:13px; color:#F5EFE8; margin:0;">Keep elbows at 45&deg;, press up and slightly in.</p>
</div>
<div style="display:grid; grid-template-columns:repeat(3, minmax(0,1fr)); gap:6px; margin-bottom:1rem;">
<div style="background:#211D18; border-radius:8px; padding:0.5rem; text-align:center;">
<p style="font-size:13px; font-weight:500; margin:0; color:#F5EFE8;">26kg &times; 8</p>
<p style="font-size:11px; color:#6B6156; margin:2px 0 0;">Best</p>
</div>
<div style="background:#211D18; border-radius:8px; padding:0.5rem; text-align:center;">
<p style="font-size:13px; font-weight:500; margin:0; color:#F5EFE8;">22kg &times; 10</p>
<p style="font-size:11px; color:#6B6156; margin:2px 0 0;">Last</p>
</div>
<div style="background:#211D18; border-radius:8px; padding:0.5rem; text-align:center;">
<p style="font-size:13px; font-weight:500; margin:0; color:#F5EFE8;">14</p>
<p style="font-size:11px; color:#6B6156; margin:2px 0 0;">Times</p>
</div>
</div>
<p style="font-size:11px; color:#6B6156; margin:0 0 5px;">Recent</p>
<div style="border-top:0.5px solid #332C22; margin-bottom:0.75rem;">
<div style="display:flex; justify-content:space-between; padding:6px 0; border-bottom:0.5px solid #332C22;"><span style="font-size:12px; color:#A89C8E;">12 Jul</span><span style="font-size:12px; color:#F5EFE8;">22&times;10 &middot; 22&times;9 &middot; 20&times;10</span></div>
<div style="display:flex; justify-content:space-between; padding:6px 0;"><span style="font-size:12px; color:#A89C8E;">8 Jul</span><span style="font-size:12px; color:#F5EFE8;">20&times;10 &middot; 20&times;10</span></div>
</div>
<button style="background:none; border:none; color:#F0997B; font-size:12px; padding:0 0 1rem;">See more</button>
<button style="width:100%; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:8px; padding:10px; display:flex; align-items:center; justify-content:center; gap:6px;">
<i class="ti ti-plus" style="font-size:16px;"></i>Add to current workout</button>
</div>
</div>
```

Note: the "Add to current workout" button is deferred and renders nowhere today. When it lands it renders **only when an ad-hoc session is active**. During a template-based session, or with no session at all, the screen shows no button — pure reference, which is what every case is today.
