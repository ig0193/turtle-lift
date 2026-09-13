# Muscle Groups tab — user flow

**Purpose:** exploration and reference. For a user who doesn't want to build a full workout and just wants to find or understand a specific exercise. This is the app's "MuscleWiki" experience — no logging happens here.

**Entry point:** Home → Muscle Groups tab.

---

## Two entry paths into the same destination

1. **Search** — a persistent search bar at the top of the tab. Typing an exercise name (e.g. "barbell curl") jumps straight to that exercise's detail page if there's a clear match, or to a short filtered list if the query is ambiguous.
2. **Browse** — tap a muscle group on the body diagram → drill into its sub-muscle groups → see a list of exercises for that sub-muscle group.

Both paths land on the same exercise detail screen — this screen is shared across the entire app (also reached from within a workout session).

## Exercise detail screen

Shown regardless of entry path (search, browse, or from inside a workout):

- **Muscle diagram — FULL BODY, not a zoomed crop.** Primary muscles fill at accent-strong, secondary at accent-light, everything else stays neutral.
  - **This reverses an earlier decision.** Exercise detail originally specced a zoomed crop from `muscle_crops.dart`. In the prototype that failed visibly: lower chest crops to a 459x69 letterbox strip that reads as a rendering bug, and at 118px wide the zoomed muscle was no more legible than the full figure. Full body also does the educational job better, since the user sees *where* the muscle sits rather than an isolated shape.
  - **If the relevant muscles span both views, both diagrams render side by side**, each full body. If one view covers everything, only that one shows, centred.
  - **Sub-muscle-group selection also uses full body**, with the parent muscle group lit. That settled the last open question: the crop system had no remaining consumer and has been deleted.
- Equipment and load type shown as two chips under the diagram(s).
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

### Recent log — last 2, then a dedicated screen

- Exercise detail shows the **last 2 sessions**, then a **"See all N sessions"** button.
- **That button navigates to a dedicated Exercise history screen — it does NOT expand inline.** This replaces the earlier "See more appends 5 per tap, page scrolls, back-to-top control appears" design. Expanding in place made an already-long detail screen much longer, and the back-to-top control existed only to paper over that. A list screen scrolls naturally and needs neither.
- The same Exercise history screen is also the destination for the **"See all N sessions"** link on the set-logging screen. One destination, one component, reached from two places.

### Exercise history screen

Full record for a single exercise. Reached from exercise detail and from the set-logging screen.

- Header: exercise name.
- Summary strip: total sessions, best, date first logged.
- **Every session, newest first**: date plus a relative date ("1 Jul · 2 weeks ago"), and each set rendered as its own pill using the standard `loadType` formatter. Showing sets individually matters — `60x10 · 60x8 · 55x10` reveals the drop-off across a session, which a single "last: 60kg x 8" hides.
- **Sessions that set a personal best carry a PB badge**, with the record-setting set highlighted in accent. Same `pbCountFor` derivation as the workout summary card. This screen is the only place the whole progression arc is visible, so marking where the records happened is what turns a log into a story.
- Paging: **"See more" appends 20 sessions per tap.** No infinite scroll.
- **Tapping a session opens the full workout it belonged to** (Session Detail in Profile), so the user can see what else they did that day.
- No empty state needed — this screen is unreachable with no history.

### Empty state — never logged

- When the user has never logged this exercise, **replace the entire history block** — all three tiles and the recent list — with a single muted line: "You haven't logged this yet."
- Do **not** render three tiles of dashes. An empty grid reads as broken; one line reads as a state.
- The diagrams, muscle legend, equipment chips and the how-to content all still render. Reference value does not depend on history.

**This tab does not log sets.** It's a pure explore/reference surface — no "log this exercise" action lives here. All logging happens in the Workout tab.

## Visiting mid-workout

- The user can freely visit the Muscle Groups tab while a workout session is active — for example, to check an alternative exercise's form cues or muscles worked before deciding what to do next. This doesn't disrupt or pause the active session.
- **When an AD-HOC session is active**, the exercise detail screen shows one additional contextual action: **Add to current workout** — this adds the exercise to the active session's exercise list as not-started, the same as if it had been found via search from inside the Workout tab. It does not log sets from here; the user logs it back in the active workout flow, consistent with logging always happening in one place.
- **When a TEMPLATE-based session is active, this action does not appear.** Template sessions are locked to their own muscle groups — an exercise outside the template cannot be added to it. See "Templates are locked to their own muscle groups" in `02-workout-tab-userflow.md` for the rationale. During a template session this tab stays pure reference, exactly as it is with no session active.
- When no session is active, the exercise detail screen shows no action beyond the reference content — there's nothing to add it to yet.
- **Summary of when the button renders:** ad-hoc session active → yes. Template session active → no. No session → no.

---

## Screen list

1. Muscle Groups tab landing (search bar + body diagram)
2. Muscle group selection (tap on body diagram)
3. Sub-muscle group selection
4. Exercise list (for a given sub-muscle group, or search results) — vertical list of compact cards: name, equipment chip, and the derived `Last: 22kg × 8` line
5. Exercise history (full record for one exercise; PB badges; reached from exercise detail and from set logging)
6. Exercise detail (shared screen — diagram(s), muscle legend, equipment + load-type chips, how-to content, Best/Last/Times tiles, paged recent log; "Add to current workout" only if an **ad-hoc** session is active)

## Animations specific to this tab

- **Muscle map highlight** — one reusable full-body component used on every screen. Interactive on the landing and sub-muscle-group screens, read-only on exercise detail. No cropped or zoomed variant exists.
- **Sub-muscle group expand/collapse** — same accordion pattern as the Workout tab.
- **Search-to-result transition** — fast, minimal-motion transition from typing a query to landing on exercise detail, since speed is the main value of search over browsing.
- **Add-to-workout confirmation** — when an ad-hoc session is active and the user taps "Add to current workout," a brief, lightweight confirmation (e.g. a small toast or button state change) confirms the exercise was added to the session — not a full logging interaction, since no sets are entered here.

## Explicitly out of scope for V1

- No rest timer.
- No celebratory full-screen animations.

---

## Sample screens (Coral theme)

Reference HTML/CSS mockups for this tab's key screens, using the Coral palette defined in `01-app-idea.md`.

### Muscle Groups tab landing

Note: this mockup uses one shape per major muscle group for simplicity. The real body diagram needs a distinct, individually tappable segment per sub-muscle group (e.g. upper/mid/lower chest as three separate regions) — see "Body diagram requirement" in `01-app-idea.md`. Tapping a specific segment should go directly into that sub-muscle group's exercise list, not into a generic parent-muscle view first.

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

Note: this mockup uses simplified placeholder shapes for both diagrams. Production must use `body-diagram-front.svg` (front) and `body-diagram-back.svg` (back), each cropped to the relevant zoomed viewBox per the reference table in `01-app-idea.md`. This example also demonstrates the front+back decision: incline dumbbell press has chest and front delts (front view) as primary/secondary, but triceps (secondary) only exists on the back view — so both diagrams are needed here, side by side.

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

Note: the "Add to current workout" button renders **only when an ad-hoc session is active**. During a template-based session, or with no session at all, the screen shows no button — pure reference.
