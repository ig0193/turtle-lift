# Profile tab — user flow

**Purpose:** a single place to see everything the app remembers on the user's behalf — history and stats, with no manual tracking required.

**Entry point:** Home → Profile tab.

---

## Sections

### My workout templates
- View all workout templates available to start a session from: predefined ones (Push day, Pull day, Leg day, Full body day, etc.) plus any custom templates the user has created.
- **Predefined templates cannot be edited directly** — they stay as-is, so they remain a reliable, unmodified reference.
- **Duplicate a predefined template** — creates an editable custom copy (e.g. "Push day (mine)"), which the user can then freely adjust. The original predefined template is untouched.
- **Create a custom template from scratch** — pick muscle groups à la carte, give it a name, save it.
- **Edit or delete a custom template** the user previously created (whether built from scratch or duplicated from a predefined one).
- This list is exactly what populates the template picker in the Workout tab's "Start workout" option — this is the only place templates are created or edited; the Workout tab only selects and runs them.
- Every template is a single, self-contained day — there is no multi-day split system or weekly rotation to configure.

### Workout history
- Chronological list of past sessions: date, muscles trained, exercises logged, sets logged. No volume figure — see `01` §Derived values.
- **Ordered by `performedOn` (the day the workout happened), not by when it was logged.** A backdated session slots into its correct historical position rather than appearing at the top. Where two sessions share a date, fall back to `loggedAt` as the tiebreaker. See the session data model in `01-app-idea.md`.
- Tap into any session for its full logged detail (every exercise and set from that session).
- **History rows show the session's resolved title** — `session.title` if set, otherwise the fallback chain in `01-app-idea.md` (template name → single exercise name → primary muscle groups trained). A row is never blank.
- **Delete a workout** — available from the session detail screen, and as a swipe action on a history row. Confirmation dialog, then permanent removal (hard delete; no tombstone in V1). All stats, the streak, personal bests, and the inline "Last time" hint on the logging screen recompute automatically, since none of them is stored — see "Derived values" in `01-app-idea.md`.
- Includes sessions from both Workout tab entry paths (template-based and ad-hoc).
- **Exercises that set a personal best are marked in the session's exercise log.** The hero card shows the count; the scrollable log below it shows *which* — a small trophy marker beside the exercise name, and the specific set that set the record highlighted in accent. This is the reason to scroll past the card: the card is the shareable summary, the log is the detail. Same `pbCountFor` derivation as the card, so the two can never disagree. Definition in `01-app-idea.md` §Progress tracking.

**Session detail is editable, and is the same component as the live workout card** — not a separate read-only viewer. Editable here: the session title, `performedOn`, the weight and reps of any set, adding or removing sets, and removing an exercise. Every edit saves immediately and all derived figures recompute on read. Being able to correct `performedOn` here is what makes the streak promise below true for past mistakes, not just for new sessions.

**The streak on a past session's card is `streakAsOf(session.performedOn)`** — the streak as it stood on that day, recomputed on every view rather than frozen at save time. It can therefore change if the user later backdates an earlier session, which is correct: the card stays historically accurate. **Session detail uses the same screenshot-friendly composition as the workout summary screen** — the same hero card (muscle map + sets/exercises/streak/calories) appears at the top, so revisiting an old workout is just as shareable as the moment it was first saved, not a one-time thing that only exists right after finishing. This card uses the standard anatomical muscle map, identical to every other screen — the mascot figure originally specced here is deferred to V2. See `01-app-idea.md`. The full exercise-by-exercise log (sets, reps, weight) is available by scrolling below the card, for the cases where the user actually wants to review what they did rather than share it.

### Ad-hoc logs
- Since these are just sessions with a single exercise, they appear in the same history list as full workouts — no separate section needed.
- Optionally tagged visually (e.g. a small "quick log" label) so the user understands why the entry looks different from a full workout.
- **Quick logs count toward the streak** on exactly the same terms as a full session: any session with at least one completed set counts for its `performedOn` date. No minimum sets.

### Stats
- **Current streak** — workout days in a row where the user never went more than **3 days** without training. Computed as `streakAsOf(today)`, never read from a stored counter; full definition, rationale for the 3-day tolerance, and data-model notes are in `01-app-idea.md`.
  - Directly below the streak stat, a short explanation of how it works — same transparency pattern as the calorie estimate, and for the same reason: a stat the user can't predict is a stat that generates angry reviews. Draft copy:

    > **How your streak works**
    > Your streak counts the workout days in a row where you never went more than 3 days without training. Rest days are fine — miss more than two in a row and it resets. Any logged session counts, including a single quick log.
    > Logged a session for an earlier date? Your streak updates to match.

  - That last line is the user-facing promise the derived model makes possible — backdating a session recalculates the streak everywhere, including on already-saved session cards.
  - **In-app nudge only:** on the final grace day, the streak stat can show a "streak ends tomorrow" hint. No notifications in V1.
- Total workouts completed.
- **Personal bests** — confirmed in V1. Derived, so no schema cost. Profile may show a lifetime PB count; the per-session count lives on each session's hero card.

### Personal details (bodyweight + gender)
- Two optional fields: bodyweight and gender. Together they're the only personal data the app collects in V1 — everything else works with zero input.
- **Bodyweight**: skippable. Until it's entered, the calorie estimate stat doesn't appear anywhere in the app (workout summary card, session detail, etc.) — that slot shows a lightweight "add weight to see calories" prompt instead, linking here.
- Directly below the bodyweight field, a short explanation of how the calorie estimate works: the MET-tier table (sets logged → light/moderate/vigorous → MET value) and a one-line honesty note that actual calories burned vary by person and effort. This is the fuller version of the same explanation available via the (i) icon on the calorie stat itself.
- No units toggle complexity needed for V1 — pick one unit (kg, matching the rest of the app's weight inputs) and keep it simple.
- **Gender**: determines which body diagram asset set is used everywhere in the app — male or female (see the body diagram requirement in `01-app-idea.md`). Options: Male / Female / Prefer not to say. Skippable, with a sensible default (the male asset set) if left unset — unlike bodyweight, gender doesn't gate any feature, it only changes which diagram renders.
- Changing gender later in Profile immediately switches the diagram set app-wide — no separate setting per screen, consistent with the uniformity rule.

---

## Screen list

1. Profile tab landing (stats summary + history list + entry into My workout templates + bodyweight field)
2. My workout templates list (predefined + custom, with a duplicate action on predefined templates)
3. Template editor (create new / edit an existing custom template — muscle group multi-select, naming)
4. Session detail (shareable hero card + full scrollable, **editable** log, for a past workout or ad-hoc entry; includes Delete workout)

## Animations specific to this tab

- **Stat count-up** — numbers (streak, total workouts, total sets) can animate with a quick count-up effect when the screen loads. A small polish touch, not a core interaction.
- **List entry transitions** — standard, fast list-item taps into session detail. Nothing elaborate; this tab is about clarity, not delight.

---

## Sample screens (Coral theme)

Reference HTML/CSS mockups for this tab's key screens, using the Coral palette defined in `01-app-idea.md`.

### Profile tab landing

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 0.5rem;">
<h1 style="margin:0.5rem 0 1rem; color:#F5EFE8;">Profile</h1>
<div style="display:grid; grid-template-columns:repeat(3, minmax(0,1fr)); gap:8px; margin-bottom:1.25rem;">
<div style="background:#211D18; border-radius:8px; padding:0.6rem; text-align:center;">
<p style="font-size:18px; font-weight:500; margin:0; color:#F5EFE8;">5</p>
<p style="font-size:11px; color:#A89C8E; margin:2px 0 0;">Day streak</p>
</div>
<div style="background:#211D18; border-radius:8px; padding:0.6rem; text-align:center;">
<p style="font-size:18px; font-weight:500; margin:0; color:#F5EFE8;">12</p>
<p style="font-size:11px; color:#A89C8E; margin:2px 0 0;">Workouts</p>
</div>
<div style="background:#211D18; border-radius:8px; padding:0.6rem; text-align:center;">
<p style="font-size:18px; font-weight:500; margin:0; color:#F5EFE8;">247</p>
<p style="font-size:11px; color:#A89C8E; margin:2px 0 0;">Sets</p>
</div>
</div>
<button style="width:100%; text-align:left; padding:0.85rem; margin-bottom:1rem; display:flex; align-items:center; justify-content:space-between; background:#211D18; border:0.5px solid #332C22; border-radius:8px; color:#F5EFE8;">
<span style="font-size:14px; font-weight:500;">My workout templates</span>
<i class="ti ti-chevron-right" style="font-size:16px; color:#6B6156;"></i>
</button>
<p style="font-size:13px; color:#A89C8E; margin:0 0 0.5rem;">History</p>
<div style="border-top:0.5px solid #332C22;">
<div style="padding:0.7rem 0; border-bottom:0.5px solid #332C22;">
<p style="font-size:14px; margin:0; color:#F5EFE8;">Push day</p>
<p style="font-size:12px; color:#6B6156; margin:2px 0 0;">Today &middot; 6 exercises &middot; 18 sets</p>
</div>
<div style="padding:0.7rem 0; border-bottom:0.5px solid #332C22;">
<p style="font-size:14px; margin:0; color:#F5EFE8;">Barbell curl</p>
<p style="font-size:12px; color:#6B6156; margin:2px 0 0;">Yesterday &middot; quick log</p>
</div>
<div style="padding:0.7rem 0;">
<p style="font-size:14px; margin:0; color:#F5EFE8;">Leg day</p>
<p style="font-size:12px; color:#6B6156; margin:2px 0 0;">2 days ago &middot; 5 exercises &middot; 21 sets</p>
</div>
</div>
</div>
<div style="display:flex; border-top:0.5px solid #332C22; margin-top:1rem;">
<div style="flex:1; text-align:center; padding:10px 0; color:#6B6156;"><i class="ti ti-barbell" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Workout</p></div>
<div style="flex:1; text-align:center; padding:10px 0; color:#6B6156;"><i class="ti ti-stretching" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Muscles</p></div>
<div style="flex:1; text-align:center; padding:10px 0; color:#D85A30;"><i class="ti ti-user" style="font-size:20px;"></i><p style="font-size:11px; margin:2px 0 0;">Profile</p></div>
</div>
</div>
```

### My workout templates list

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 0.5rem;">
<div style="display:flex; align-items:center; gap:8px; margin-bottom:1rem;">
<i class="ti ti-arrow-left" style="font-size:18px; color:#A89C8E;"></i>
<h2 style="margin:0; color:#F5EFE8;">My workout templates</h2>
</div>
<p style="font-size:11px; color:#6B6156; margin:0 0 6px;">Predefined</p>
<div style="border-top:0.5px solid #332C22; margin-bottom:1rem;">
<div style="display:flex; align-items:center; justify-content:space-between; padding:0.7rem 0; border-bottom:0.5px solid #332C22;">
<div><p style="font-size:14px; margin:0; color:#F5EFE8;">Push day</p><p style="font-size:12px; color:#6B6156; margin:2px 0 0;">Chest, shoulders, triceps</p></div>
<i class="ti ti-copy" style="font-size:16px; color:#6B6156;"></i>
</div>
<div style="display:flex; align-items:center; justify-content:space-between; padding:0.7rem 0; border-bottom:0.5px solid #332C22;">
<div><p style="font-size:14px; margin:0; color:#F5EFE8;">Pull day</p><p style="font-size:12px; color:#6B6156; margin:2px 0 0;">Back, biceps</p></div>
<i class="ti ti-copy" style="font-size:16px; color:#6B6156;"></i>
</div>
<div style="display:flex; align-items:center; justify-content:space-between; padding:0.7rem 0;">
<div><p style="font-size:14px; margin:0; color:#F5EFE8;">Leg day</p><p style="font-size:12px; color:#6B6156; margin:2px 0 0;">Quads, hamstrings, glutes, calves</p></div>
<i class="ti ti-copy" style="font-size:16px; color:#6B6156;"></i>
</div>
</div>
<p style="font-size:11px; color:#6B6156; margin:0 0 6px;">Custom</p>
<div style="border-top:0.5px solid #332C22; margin-bottom:1rem;">
<div style="display:flex; align-items:center; justify-content:space-between; padding:0.7rem 0;">
<div><p style="font-size:14px; margin:0; color:#F5EFE8;">Push day (mine)</p><p style="font-size:12px; color:#6B6156; margin:2px 0 0;">Duplicated from Push day</p></div>
<i class="ti ti-edit" style="font-size:16px; color:#6B6156;"></i>
</div>
</div>
<button style="width:100%; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:8px; padding:10px; display:flex; align-items:center; justify-content:center; gap:6px;">
<i class="ti ti-plus" style="font-size:16px;"></i>Create custom template</button>
</div>
</div>
```

### Template editor

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 0.5rem;">
<div style="display:flex; align-items:center; gap:8px; margin-bottom:1rem;">
<i class="ti ti-arrow-left" style="font-size:18px; color:#A89C8E;"></i>
<h2 style="margin:0; color:#F5EFE8;">Edit template</h2>
</div>
<p style="font-size:11px; color:#A89C8E; margin:0 0 4px;">Name</p>
<input type="text" value="Push day (mine)" style="width:100%; margin-bottom:1rem; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:8px; padding:8px;" />
<p style="font-size:11px; color:#A89C8E; margin:0 0 8px;">Muscle groups targeted</p>
<div style="display:flex; flex-wrap:wrap; gap:8px; margin-bottom:1.25rem;">
<span style="background:#33221A; color:#F0997B; font-size:12px; padding:6px 12px; border-radius:8px; display:flex; align-items:center; gap:4px;">Chest <i class="ti ti-x" style="font-size:12px;"></i></span>
<span style="background:#33221A; color:#F0997B; font-size:12px; padding:6px 12px; border-radius:8px; display:flex; align-items:center; gap:4px;">Shoulders <i class="ti ti-x" style="font-size:12px;"></i></span>
<span style="background:#33221A; color:#F0997B; font-size:12px; padding:6px 12px; border-radius:8px; display:flex; align-items:center; gap:4px;">Triceps <i class="ti ti-x" style="font-size:12px;"></i></span>
<span style="border:0.5px dashed #6B6156; color:#6B6156; font-size:12px; padding:6px 12px; border-radius:8px; display:flex; align-items:center; gap:4px;"><i class="ti ti-plus" style="font-size:12px;"></i> Add muscle group</span>
</div>
<button style="width:100%; background:#D85A30; color:#1B0C05; border:none; border-radius:8px; padding:10px; font-size:14px; font-weight:500;">Save template</button>
</div>
</div>
```

### Personal details (bodyweight + gender)

```html
<div style="background:#17140F; border-radius:16px; padding:0; max-width:340px; overflow:hidden;">
<div style="padding:1.25rem 1.25rem 1.5rem;">
<div style="display:flex; align-items:center; gap:8px; margin-bottom:1rem;">
<i class="ti ti-arrow-left" style="font-size:18px; color:#A89C8E;"></i>
<h2 style="margin:0; color:#F5EFE8;">Personal details</h2>
</div>
<p style="font-size:11px; color:#A89C8E; margin:0 0 8px;">Gender (optional)</p>
<div style="display:flex; gap:8px; margin-bottom:0.5rem;">
<span style="background:#33221A; color:#F0997B; font-size:12px; padding:8px 14px; border-radius:8px; border:0.5px solid #D85A30;">Male</span>
<span style="background:#211D18; color:#A89C8E; font-size:12px; padding:8px 14px; border-radius:8px; border:0.5px solid #332C22;">Female</span>
<span style="background:#211D18; color:#A89C8E; font-size:12px; padding:8px 14px; border-radius:8px; border:0.5px solid #332C22;">Skip</span>
</div>
<p style="font-size:11px; color:#6B6156; margin:0 0 1.25rem;">Chooses which body diagram is used throughout the app. Defaults to the diagram shown above if skipped.</p>
<p style="font-size:11px; color:#A89C8E; margin:0 0 4px;">Bodyweight (optional)</p>
<div style="display:flex; align-items:center; gap:8px; margin-bottom:0.5rem;">
<input type="text" placeholder="70" style="width:80px; background:#211D18; border:0.5px solid #332C22; color:#F5EFE8; border-radius:8px; padding:8px; text-align:center;" />
<span style="font-size:13px; color:#A89C8E;">kg</span>
</div>
<p style="font-size:11px; color:#6B6156; margin:0 0 1.25rem;">Used only to estimate calories burned. Skip if you'd rather not — the calorie stat just won't appear anywhere until this is set.</p>
<div style="background:#211D18; border-radius:8px; padding:0.85rem; margin-bottom:1rem;">
<p style="font-size:12px; color:#F5EFE8; font-weight:500; margin:0 0 8px;">How the calorie estimate works</p>
<div style="display:flex; justify-content:space-between; font-size:11px; color:#A89C8E; padding:4px 0; border-bottom:0.5px solid #332C22;"><span>1&ndash;9 sets</span><span>Light effort</span></div>
<div style="display:flex; justify-content:space-between; font-size:11px; color:#A89C8E; padding:4px 0; border-bottom:0.5px solid #332C22;"><span>10&ndash;20 sets</span><span>Moderate effort</span></div>
<div style="display:flex; justify-content:space-between; font-size:11px; color:#A89C8E; padding:4px 0 8px;"><span>21+ sets</span><span>Vigorous effort</span></div>
<p style="font-size:11px; color:#6B6156; margin:0;">Based on standard exercise-science averages for resistance training. Actual calories burned vary by person and effort.</p>
</div>
<button style="width:100%; background:#D85A30; color:#1B0C05; border:none; border-radius:8px; padding:10px; font-size:14px; font-weight:500;">Save</button>
</div>
</div>
```

