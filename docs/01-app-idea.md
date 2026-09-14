# App idea — overview, V1 scope & feature list

> **Implementing? Start with `00-build-spec.md`** — the terse rules-and-tables digest. This document holds the reasoning behind those rules and wins any conflict with the digest.

> **App name: TBD.** Not blocking development — build and reference the app as "[App Name]" or a working codename until this is decided. Direction: single word, invented/abstract rather than descriptive (in the spirit of Strava, Hevy, Duolingo) — not a literal gym-word compound. Candidates explored so far (unverified — run through a proper domain-checking tool like Namelix or a registrar's bulk search before committing): Kelvra, Rivalo, Brindo, Nyvo, Kaldera. Confirmed **unavailable/collides with an existing product**: Bodmap, Gympact, IronLog, RepLog, RepCanvas, GymGo, LiftMark, SetMark, RepMark (repmark.io exists), Vamo, Torqe/Torq, Flynt.

> **The goal of Product #1 is not to build the best gym app. The goal is to become someone who can repeatedly take an idea from concept → build → deploy → real users → feedback → iteration.**

---

## Goal

- Build a gym companion that reduces decision fatigue for beginners.
- Help users confidently complete workouts.
- Build the habit of showing up consistently.
- Ship a real product that people can use.

## Who it's for

- People new to the gym.
- People who know they should work out but don't know exactly what to do.
- People following YouTube trainers or gym trainers but wanting an easy way to remember and log workouts.

## Not trying to be

- An AI fitness coach.
- A nutrition app.
- A calorie tracking app — the app shows one rough, clearly-labeled calorie *estimate* per session as a fun/motivational stat (see Progress tracking below), but this is not calorie tracking: no goals, no budgets, no logging food, no daily totals, no claim of precision.
- A social fitness platform.
- A replacement for a personal trainer.

## Core philosophy

- Reduce thinking inside the gym.
- Make logging effortless.
- Remember everything so the user doesn't have to.
- Progress over perfection.
- Simplicity over hundreds of features.

## Success criteria (product-level)

- A first-time user can start their first workout within 60 seconds.
- A user doesn't need a notebook to remember previous workouts.
- A beginner feels less confused after opening the app.

---

## App structure

- Splash screen — no login, no signup. Straight into the app.
- Splash leads directly to the home screen.
- Home screen has three tabs: **Workout | Muscles | History**. Profile is reached from an avatar in the header, not a tab (see `docs/adr/0003-l0-navigation-variant-a.md`).
- No onboarding wizard. First-time and returning users land in the same place.

| Tab | Purpose |
|---|---|
| **Workout** | Start a workout session — by choosing a saved workout template, or by building an ad-hoc session via exercise search. |
| **Muscle Groups** | Explore and reference — browse by body diagram or search by exercise name. Pure reference; no logging happens here. Can add an exercise to an active workout session if one is running. |
| **Profile** | Workout history, stats, streak, and managing/creating workout templates. |

Note: the app doesn't suggest or auto-select a workout for the user (no "today's workout" recommendation) — there's no AI or rotation logic in V1. There is also no multi-day split system or weekly rotation of any kind — every workout template is a single, self-contained day (e.g. "Push day"), not part of a sequence. The user always actively chooses which template to run, or goes ad-hoc.

---

## V1 feature list

### Workout templates
- Predefined, **single-day** templates — each one is self-contained, with no multi-day rotation or weekly split system behind it. Eleven ship; the authored set and each one's split membership live in `lib/src/data/workout_templates.dart`, which is the single source of truth for both:
  - Push day (chest, shoulders, triceps)
  - Pull day (back, biceps)
  - Leg day (quads, hamstrings, glutes, calves)
  - Upper body day (chest, back, shoulders, arms — "arms" is not a parent group, so it is stored as biceps + triceps)
  - Full body day (a mix across all major muscle groups)
  - Chest and triceps day
  - Back and biceps day
  - Shoulders day
  - Arms day (biceps and triceps)
  - Chest day
  - Back day
- Each predefined template has a short explanation of what it means.
- **Predefined templates cannot be edited directly** — they stay as a reliable, unmodified reference. A user can duplicate one into an editable custom copy instead.
- **A template stores parent muscle groups only** (e.g. `['chest','shoulders','triceps']`). Sub-muscle groups are **derived from the muscle taxonomy at render time**, never copied into the template. Picking "chest" in the template editor therefore surfaces upper, mid and lower chest automatically; the user does not select bands individually.
  - Benefit of deriving rather than storing: if a sub-muscle group is ever added to the taxonomy (e.g. a real side-delt segment), every existing template picks it up with no data migration.
  - **A template is a curated shortlist to browse within, not a plan to complete.** Nothing in a template is ever "finished", and no muscle group has a completion state. This is why a seven-row Push day is unremarkable — seven options in a menu, not seven unchecked boxes.
  - **Templates are locked to their own muscle groups during a session.** An exercise outside the template's muscle groups cannot be added to a template-based session. Keeping the template coherent is the reason for choosing one; users who don't have a fixed plan should use the ad-hoc path instead. Full rationale and the accepted friction are documented in `02-workout-tab-userflow.md`.
- User can create a fully custom template from scratch by picking muscle groups à la carte, give it a name, and save it for reuse. Template creation and management lives behind the Profile avatar; the Workout tab is just for starting a session from an already-saved template.
- User can build a one-off ad-hoc workout by searching and adding exercises directly, without any template or muscle-group structure. This is not saved as a reusable template — it's a single session.

### Exercise library
Each exercise entry contains:
- Name
- Primary muscle group(s)
- Secondary muscle group(s)
- Equipment required
- Alternative/equivalent exercises (exercises that train the same muscles differently, e.g. machine chest press vs. flat dumbbell press)
- Short form cues (text only, no video)
- A visual representation showing primary vs. secondary muscles worked

### Muscle training state

- **No muscle group, at any level, has a completion state in the data model.** Only exercises are marked complete. A sub-muscle group being shown as trained is a *visualisation* of the exercises the user completed, not a stored fact about the muscle.
- **`trained` is derived**: a sub-muscle group is `trained` in a session when at least one completed exercise in that session lists it among its **primary** muscles. Secondary muscles never contribute.
- The field is named **`trained`, not `done`** — "done" implies a target the app deliberately does not set.
- The same derivation drives two different surfaces, which deliberately disagree:
  - **Muscle map fill** uses primary *and* secondary muscles (strong accent and light accent respectively) — it answers *"what got worked"*.
  - **The sub-muscle group tick** in the workout overview list uses **primary only** — it answers *"what have I trained directly"*.
  - This divergence is intentional. Without it, a chest press would tick the triceps row on a Push day and lead the user to believe triceps was handled when they had not done a single triceps movement.

### Muscle group hierarchy
- Muscle groups are broken into sub-muscle groups wherever applicable (e.g. Chest → Upper / Mid / Lower). This hierarchy underlies both the Workout flow and the Muscle Groups tab.

- **The taxonomy is a generated data file, not prose — `body-diagrams/generate_muscle_taxonomy.py` emits `muscle_taxonomy.json` and `muscle_taxonomy.dart`. Build against those, not against this table.** The table below is generated from the same source, so it cannot disagree with the code, but the data file is authoritative. The generator validates itself against the SVG assets and fails the build if a sub-muscle group has no segment, or if a segment exists that no sub-muscle group claims.

  **12 parent groups, 19 sub-muscle groups, exactly 1 mapping exception, 0 orphan segments.**

| Parent | Sub-muscle group | Diagram segment(s) filled | Note |
|---|---|---|---|
| Chest | **Upper chest** (`chest/upper`) | `front` → `chest/upper` |  |
| Chest | **Mid chest** (`chest/mid`) | `front` → `chest/mid` |  |
| Chest | **Lower chest** (`chest/lower`) | `front` → `chest/lower` |  |
| Back | **Upper back & traps** (`back/upper`) | `front` → `back/upper`<br>`back` → `back/upper` |  |
| Back | **Lats** (`back/lats`) | `back` → `back/lats` |  |
| Back | **Lower back** (`back/lower`) | `back` → `back/lower` |  |
| Shoulders | **Front delt** (`shoulders/front-delt`) | `front` → `shoulders/front-delt` |  |
| Shoulders | **Side delt** (`shoulders/side-delt`) | `front` → `shoulders/front-delt` | no artwork of its own; shares another segment |
| Shoulders | **Rear delt** (`shoulders/rear-delt`) | `back` → `shoulders/rear-delt` |  |
| Biceps | **Biceps** (`biceps/biceps`) | `front` → `biceps/biceps` |  |
| Triceps | **Triceps** (`triceps/triceps`) | `back` → `triceps/triceps` |  |
| Forearms | **Forearms** (`forearms/forearms`) | `front` → `forearms/forearms`<br>`back` → `forearms/forearms` |  |
| Abs | **Upper abs** (`abs/upper`) | `front` → `abs/upper` |  |
| Abs | **Lower abs** (`abs/lower`) | `front` → `abs/lower` |  |
| Obliques | **Obliques** (`obliques/obliques`) | `front` → `obliques/obliques` |  |
| Quads | **Quads** (`quads/quads`) | `front` → `quads/quads` |  |
| Hamstrings | **Hamstrings** (`hamstrings/hamstrings`) | `back` → `hamstrings/hamstrings` |  |
| Glutes | **Glutes** (`glutes/glutes`) | `back` → `glutes/glutes` |  |
| Calves | **Calves** (`calves/calves`) | `front` → `calves/calves`<br>`back` → `calves/calves` |  |

  Rules that fall out of this table:
  - **Templates store parent ids only.** Sub-muscle group rows are derived from `kMuscleTaxonomy` at render time.
  - **A sub-muscle group can fill segments in both views** — upper back, forearms and calves each appear on the front *and* back diagram. This is normal, not an exception; resolve by matching `data-muscle-group` + `data-sub-muscle-group` across whichever view is currently displayed.
  - **Parents with a single sub-muscle group render as one flat row, no accordion** (biceps, triceps, forearms, obliques, quads, hamstrings, glutes, calves). Expanding "Biceps" to reveal a single "Biceps" row is pointless UI. Only chest, back, shoulders and abs accordion.
  - **Traps lives under `back`, not `shoulders`.** The trapezius shape is visible on both diagrams, and earlier asset versions filed the front-view shape under `shoulders/traps` while the back-view shape sat under `back/upper` — the same muscle in two different parent groups depending on which way the figure faced. Both front SVGs have been re-tagged to `back/upper` ("Upper back & traps"), so this now needs no special-case handling at all. Traps is trained by upper-back work, so `back` is the parent that matches where users will look for it.
- **Body diagram requirement — segments must be explicit, not just parent muscle groups.** The body diagram used throughout the app must render each *sub-muscle group* as its own distinct, separately colorable/tappable region — not a single shape for the whole parent muscle group. For example, the chest needs to visually show upper, mid, and lower chest as three separate segments, not one blob labeled "chest." This matters for two reasons: (1) the entire point of the muscle map is showing *which specific sub-muscle group* was targeted — a single-shape chest region can't communicate that; (2) in the Muscle Groups tab, tapping a specific segment (e.g. upper chest) should take the user directly into that sub-group, not into a generic "chest" view that then requires a second selection step.
  - This applies to every muscle group with defined sub-groups, not just chest — shoulders (front/side/rear delt), legs (quads/hamstrings/glutes/calves), back (lats/upper back/lower back), etc.
  - **Known limitation: triceps is not split by head** (long head / lateral head) in the delivered assets — it's one undivided segment on the back view. The muscle taxonomy could theoretically support that level of detail, but the traced source art didn't provide it. Same category of gap as the side-delt issue below — not worth blocking on for V1.

- **Final reference assets — use these, not the earlier placeholder mockups:**
  - `body-diagram-front.svg` + `body-diagram-back.svg` (male set), and `body-diagram-front-female.svg` + `body-diagram-back-female.svg` (female set) — real anatomical body diagrams, traced from licensed reference artwork rather than hand-drawn approximations. Each `<g class="muscle-segment">` has `data-muscle-group` and `data-sub-muscle-group` attributes matching this app's muscle taxonomy, ready to wire up to `GestureDetector`s and fill-state logic in Flutter. The female views expose an **identical set of `data-sub-muscle-group` values** to their male counterparts (12 front, 9 back), so app logic only needs to pick which file pair to load based on the gender field, never branch its interaction logic.

    **Important implementation detail:** identical *taxonomy* does not mean identical *element count*. The male front view has 13 segment elements for its 12 sub-muscle groups, because the serratus shape renders as its own visual piece while carrying `data-sub-muscle-group="obliques"` and routing to the obliques region. **Always select every element matching a `data-sub-muscle-group` value — never just the first match.** Writing `querySelector`-style "first hit" logic will silently fail to fill part of the male obliques.
  - Coverage (identical across male and female, front view, 12 segments): chest (upper/mid/lower), abs (upper/lower), obliques, biceps, front delt, upper back & traps, quads, forearms, calves. Coverage (identical across male and female, back view, 9 segments): lats, upper back & traps, lower back, rear delt, triceps, glutes, hamstrings, forearms, calves. Note the front view's trapezius shape is tagged `back/upper`, matching the back view — see the traps note above.
  - **Side delt — the single mapping exception, and the one thing to get right here.** Side delt is a first-class sub-muscle group in the taxonomy (it has its own list row, its own exercises, and its own tick), but it has **no artwork of its own**. It maps to the front view's `shoulders/front-delt` segment. Three points, in order of how easy they are to get wrong:
    1. **Front view only.** An earlier version of this document said to route side delt "through front-delt (front view) or rear-delt (back view)." That is wrong and must not be implemented: it would make one lateral raise appear to have trained the rear delt as soon as the user flipped the diagram, asserting something false about two muscles the user never touched.
    2. **Why this shape is a defensible home.** The traced "front delt" shape reaches x=168 at shoulder height, which is exactly the outermost body geometry at that height — it depicts the *entire visible shoulder cap from the front*, including the side delt's front-facing surface. The segment is under-labeled rather than wrong. Its display name on the diagram should therefore read **"Shoulder (front)"**, not "Front delt", so the map stops claiming precision it doesn't have. The taxonomy still lists three separate delts; only the diagram's label collapses to two regions.
    3. **Do not drop side delt from the taxonomy to avoid this.** That was considered and rejected: lateral raises would then have to be filed as primary *front* delt, which is anatomically wrong. Shipping incorrect primary-muscle data is a worse failure than an imprecise diagram in an app whose stated purpose is teaching beginners which muscles they're training.

    **Known residual wart, accepted for V1:** after a lateral raise the front shoulder region fills at strong accent while the "Front delt" row stays unticked and "Side delt" ticks. This is the same class as the intentional map/list divergence documented under "Muscle training state", but it is real. The only true fix is a 3/4-angle reference image and a traced side-delt segment — parked for V2.
  - A front/back toggle (e.g. a flip icon) is the natural UI pattern for switching between the two views, since together they're needed for full-body coverage. Add a gender toggle (or read it from the Profile field) alongside this to pick the asset pair.
  - Each SVG's `<desc>` tag documents labeling confidence per segment and any grouping decisions — read this before wiring up interactions, since a few segments were assigned by position rather than fully visually confirmed. Two non-canonical shapes are handled specifically, consistently across all four files:
    - **Knee / quad tie-in — decorative, not tappable.** It renders as plain body silhouette (`id="silhouette-knee-tie-in"`, `aria-hidden`, no data attributes). It is not a muscle group and must not appear in any checklist or muscle map fill. Male front was previously the only file missing this correction; that has been fixed.
    - **Serratus — folded into obliques.** Present in the male front source art only; the female source art doesn't draw it, and it has deliberately *not* been invented for the female asset. In the male front it keeps its own element id but carries `data-sub-muscle-group="obliques"`, so tapping or highlighting it behaves exactly like the obliques region.

- **Uniformity rule — every muscle map on every screen must come from the traced SVG assets. No screen gets its own separate or simplified diagram.** This is a hard requirement, not a preference — a beginner-focused app loses trust fast if the body diagram looks slightly different from screen to screen. There are now **two asset sets — male and female** — selected via the gender field in Profile (see `04-profile-tab-userflow.md`); everything below applies identically to whichever set is active. Two display modes only:
  - **Full view** — the entire `body-diagram-front.svg` or `body-diagram-back.svg`, unmodified viewBox, used exactly as-is. Used for the private, in-app screens where multiple muscle groups are shown at once but nothing is being shared publicly: Workout Overview and Muscle Groups tab landing.
  - **Zoomed view** — the exact same SVG file, same paths, same colors, just rendered with a tighter `viewBox` cropped to one muscle group's bounding box. This is not a different asset or a redrawn icon — it's the identical markup, viewed through a smaller window. Used wherever only one muscle matters: Exercise Detail, and the intermediate "sub-muscle group selected" step in both the Workout tab and Muscle Groups tab.
    - **Decision: when an exercise's primary/secondary muscles span both the front and back views** (e.g. incline press: chest is front, triceps is back), Exercise Detail shows **both diagrams side by side** — each zoomed to its own relevant region(s), using the same crop rules below. If every relevant muscle for that exercise is in one view only, only that one diagram is shown — no empty second diagram just for symmetry.

- **Mascot figure — deferred to V2. V1 uses the anatomical diagram everywhere, with no exceptions.**

  The shareable screens (Workout Summary / share card, and Session Detail) originally specced a third display mode: a stylised mascot character with coarse lit zones. **This has been dropped from V1.** Those two screens now use the same traced anatomical diagram as the rest of the app, lit the same way — strong accent for primary, light accent for secondary, neutral for untrained.

  This restores the uniformity rule to being absolute: **every body figure in V1 comes from the four traced SVGs, on every screen, with no third mode and no exceptions.** It also removes the project's only hard design dependency — nothing in V1 is blocked on an asset that doesn't exist.

  **The two problems that originally motivated the mascot, and where they stand:**
  1. **Groin / glute area visible on a shared screenshot — resolved, and it was never real for these assets.** Verified directly against `body-diagram-front.svg`: the traced figure is composed *entirely* of muscle segments with no background silhouette, so there is no pelvis or crotch geometry at all. The abdominal V-taper lines simply end and the quads begin, leaving a clean gap. Nothing to be self-conscious about.
  2. **Sparse figure after an upper-body session — mitigated by reusing an existing rule.** The share card shows **only the view or views containing trained muscles, side by side when both apply** — the same front/back conditional already specced for Exercise Detail. A push day lights chest and front delts on the front view and triceps on the back view, so neither diagram sits empty. A session confined to one view shows that one view, filling the card rather than leaving half of it grey.

  **Resolved differently: the mascot is now a turtle, and it is not a body diagram at all.** See `mascot-brief.md`. A stylised creature sidesteps the problem entirely — there are no zones to light, no anatomy to get wrong, and no share-card role to fill, because the anatomical map already does that job well. The turtle is a decorative companion with four states (resting, lifting, pleased, hidden) that lives on the workout overview, celebration screens and empty states.

**The zone-lit human figure is dead.** Do not revive it.

**One hard rule carried into that brief:** the turtle never reacts to inactivity — no decay, no sad states, no notifications, and the tap easter egg unlocks nothing. A pet is the strongest available vehicle for exactly the shaming and achievement mechanics this app rules out.

  - **Zoom crop rule:** for muscles where left and right sit close together on the torso (chest, abs, obliques, traps, lats, lower back, glutes), the zoomed viewBox includes both sides combined. For limb muscles where left and right are naturally far apart in a T-pose reference (biceps, forearms, triceps, front delt, rear delt, quads, hamstrings, calves), the zoomed viewBox crops to **one side only** — showing both would mean zooming out to nearly full-body width, defeating the purpose. This reads naturally since these exercises train both sides symmetrically anyway.
  - **No zoomed or cropped views anywhere in V1 — every diagram renders the full body at its unmodified viewBox.** The crop system that previously lived here (`muscle_crops.json`, `muscle_crops.dart`, `generate_muscle_crops.py`) has been **deleted**.
    - Why: its two consumers were Exercise Detail and sub-muscle-group selection, and prototyping killed both. Lower chest crops to a 459x69 letterbox strip that reads as a rendering bug, and at ~118px wide a zoomed muscle was no more legible than the whole figure. Full body also does the educational job better — the user sees where a muscle sits rather than an isolated shape.
    - Full viewBoxes, the only diagram values still needed:

      | Asset | viewBox |
      |---|---|
      | `body-diagram-front.svg` | `0 0 700 1324` |
      | `body-diagram-back.svg` | `0 0 712 1324` |
      | `body-diagram-front-female.svg` | `0 0 700 1268` |
      | `body-diagram-back-female.svg` | `0 0 704 1252` |

    - The four assets do not share a coordinate space, so never assume a value computed against one applies to another.

### Workout sessions
- A workout is a session — a container holding every exercise and set logged in that sitting.
- Every logged set belongs to a session, including single ad-hoc exercises (an implicit lightweight session is created automatically if none is active).
- **Every session carries two distinct date fields — do not collapse them into one:**
  - `performedOn` — a **local calendar date** (year/month/day, no time, no timezone). This is the day the workout actually happened, and it is the only field that feeds streaks, history ordering, and "Today / Yesterday" labels. Storing it as a UTC timestamp is a bug: a 11pm session would land on the wrong day for the user.
  - `loggedAt` — a full timestamp for when the rows were actually written. Used for debugging and as a tiebreaker when two sessions share a `performedOn`. Never shown to the user.
- `performedOn` **defaults to today and is user-editable**, so retrospective logging is a first-class path rather than something the user has to work around. See the session date control in `02-workout-tab-userflow.md`.
- **Every session has an optional user-editable `title`** (max 40 characters — it is the hero text on a ~300px-wide share card).
  - Prefilled with the template name on the template path; **starts empty** on the ad-hoc path. The user is never blocked on naming a session, and can set or change the title on the summary card after finishing, or never.
  - **`title` may be empty in storage, but must never be displayed empty.** Resolve it for display with this fallback chain, in order — this is the single source of truth for what any screen shows as a session's name:
    1. `session.title`, if non-empty
    2. The template name (`Push day`) — template-based sessions
    3. The single exercise's name (`Barbell curl`) — quick logs
    4. The primary muscle groups trained, comma-separated (`Chest, triceps`)
  - **Do not auto-generate a time-of-day title** ("Evening workout") as the fallback. With retrospective logging the log time is not the workout time, so it would be wrong on any backdated session. Nothing stops the user typing it themselves.
- **An active session persists indefinitely** — never auto-discarded on close, date change, or timeout. Only one may be active at a time. Returning to the Workout tab shows the open session in place of the landing — it takes the tab over, with no Resume card. Starting a new workout auto-saves the open one if it has at least one completed set (keeping its original `performedOn`) or discards it silently if empty. Full rules in `02-workout-tab-userflow.md` Step 2b.
- `performedOn` is **clamped to today or earlier** — future-dated sessions are not accepted, since they'd make the streak calculation meaningless.

### Derived values — a general rule

**Every aggregate the app displays is computed on read from the logged sets. None of them is stored on the session row.** This applies to: workout streak, exercise and set counts, personal bests, the estimated calorie figure, and the `trained` tick on a sub-muscle group.

**Total lifted volume (kg) is deliberately NOT tracked in V1.** It cannot be computed honestly: it silently excludes all 50 bodyweight exercises and all 14 timed exercises, so a session containing dips, pull-ups or planks under-reports with no indication that it has done so. **Set count is the headline volume proxy instead** — it is countable for every load type, it is already the input to the calorie estimate, and it is already the stated stand-in for workout duration. Progressive overload is surfaced through personal bests and the inline "Last time" hint, both of which are per-exercise and therefore meaningful in a way session volume never was. Volume is derived, so this is a reversible decision: nothing needs migrating if it is added back later.

The reason is that sessions are editable and deletable after the fact — a weight can be corrected, a set removed, a date changed, a whole session deleted. Any denormalised aggregate would immediately go stale and would need repair logic on every one of those paths. Deriving on read makes all of them correct by construction. There is no performance argument against it at V1 scale: a few thousand sessions of local data recompute instantly, and anything hot can be cached in memory.

**Specifically: deleting a session must remove its contribution from the streak, all Profile stats, personal bests, and the inline "Last time: 22kg × 10" hint on the logging screen.** With derived values this happens automatically. Do not introduce a stored counter anywhere without re-reading this section.

### Progress tracking
- Previous session's weights shown inline when logging.
- **No "average weight" statistic anywhere.** It was previously specced on Exercise Detail; it is meaningless for `bodyweight`, `assisted` and `timed` exercises, and less actionable than "last session" even for `weighted` ones. Exercise Detail shows Best / Last / Times instead — see `03-muscle-groups-tab-userflow.md`.
- Full workout history.
- **Personal bests — confirmed in V1.** Derived, no schema cost. Definition and per-`loadType` metrics are under "Set logging by loadType" below. Two rules govern when a session is credited with a PB:
  - **A PB requires at least one prior logged session of that exercise.** The first time a user ever performs an exercise, that set is trivially their maximum — but badging it as a personal best would give a beginner "6 personal bests" on their very first workout, then near-zero afterwards. That is precisely the wrong motivational curve for this app's target user. First occurrence gets no badge.
  - **A PB must be strictly greater than the previous best.** Repeating an identical set is not a new record. This matches the existing tie rule (ties resolve to the earliest date).
- **Per-session PB count.** `pbCountFor(session)` = the number of *exercises* in that session whose best set beat the user's best for that exercise across all sessions with an earlier `performedOn`. Counted per exercise, not per set — three progressively heavier sets that all beat the old record are one PB, not three.
  - Derived on read like everything else, so a backdated session can retroactively remove a PB badge from a later one (log a 100kg bench on Wednesday, then backdate a 105kg Monday, and Wednesday is no longer a record). Same behaviour as the streak, and correct for the same reason — but worth knowing, since a vanishing badge reads worse than a changing number.
  - **Implementation note:** compute as a single chronological pass over all completed sets, tracking a running best per exercise and marking each point where it strictly increases. Do not evaluate each session against full history independently — that is O(n²) and will visibly lag the history list. One pass, cached in memory.
- Total workouts completed.
- Exercises logged per session (used in place of duration — see note below).
- **Workout streak** — the count of workout days in a row where the user never went more than **3 days** without training.
  - **Tolerance is 3 days**, meaning the gap between two consecutive workout dates must be `<= 3` for the chain to continue. This number is deliberate, not arbitrary: a Friday → Monday gap is 3 days, so a tighter 2-day rule would break the streak of anyone training weekdays-only, and of anyone running the Push/Pull/Leg split on Mon/Wed/Fri — which is exactly the pattern this app's own headline templates encourage. A 2-day rule would reset the streak of a large share of well-behaved users every single weekend. Going looser (4+) makes the streak unearned. Note that no gap-based rule can accommodate weekend-only training; that's an accepted limitation for V1.
  - **Any session with at least one completed set counts, including single-exercise quick logs.** No minimum set count. This matches "progress over perfection," is trivial to explain in one sentence, and there's no social layer or leaderboard for anyone to game.
  - **Derived, never stored.** The streak is a pure function of the set of distinct `performedOn` dates:

    ```
    streakAsOf(date) -> int
      walk backwards from `date` through distinct workout dates,
      chaining while gap <= 3 days
    ```

    The Profile hero calls `streakAsOf(today)`. A past session's hero card calls `streakAsOf(session.performedOn)`. Same function, one parameter.
  - **Why derived rather than stored on the session:** if a user logs Wednesday and then backdates a Monday session, Wednesday's streak *should* become 2. With a derived value that happens for free — nothing was written down to go stale. Storing an incremented counter would need repair logic on every backdate, date-edit and delete, and would still drift. There is no performance argument for storing it: five years at 5 sessions a week is ~1,300 dates, so a full backward scan on render is free. Cache in memory if it ever shows up in a profile.
  - **The streak must decay against today, not just against the stored data.** If the last session was 5 days ago, `streakAsOf(today)` returns 0 even though nothing in storage changed. Getting this wrong produces the "app said 12, opened it a week later, still says 12" bug.
  - **Consequence for shareable cards:** a past session's hero card shows the streak *as it stood on that date*, so it can legitimately change later if the user backdates an earlier session. This is correct behaviour — the card is historically accurate rather than a frozen snapshot. Worth knowing when reading the Session Detail section of `04-profile-tab-userflow.md`.
  - **In-app nudge (no notifications):** since the last workout date is known, Profile can show a "streak ends tomorrow" hint on the final grace day. This stays in-app only — notifications are out of scope for V1.
  - The user-facing explanation of all of this lives next to the streak stat in Profile — see `04-profile-tab-userflow.md`. Same transparency pattern as the calorie estimate.
- **Naming: these are "personal bests", not "achievements".** There is no achievement or badge framework in V1 — no streak milestones, no workout-count trophies, no unlockables. Keeping the user-facing name literal is deliberate, so that a single PB counter does not become the seed of a general achievements system.
- **Estimated calories burned** — a rough, clearly-labeled per-session estimate, shown as one of the hero stats on the workout summary / shareable card.
  - **Gated behind bodyweight**: calories are not shown at all until the user has entered their bodyweight in Profile (see `04-profile-tab-userflow.md`). Until then, that stat slot shows a lightweight "add weight to see calories" prompt instead of hiding silently or showing a wrong number. This is the first piece of personal data the app collects — everything else in V1 works with zero personal input.
  - **Formula**: `kcal = (MET × 3.5 × bodyweight_kg / 200) × estimated_minutes`, where `estimated_minutes = total_sets_in_session × 42.5 seconds / 60`.
  - **MET is a simple 3-tier lookup based on total sets logged in the session** — not a dynamic per-session calculation:

    | Sets logged | Effort tier | MET |
    |---|---|---|
    | 1–9 | Light | 3.5 |
    | 10–20 | Moderate | 5.0 |
    | 21+ | Vigorous | 6.0 |

  - Displayed as a plain number with no approximation sign (e.g. "185 kcal") — the (i) icon and the Personal details explainer carry the honesty about it being an estimate, so the prefix is redundant clutter on a share card, not a range — the approximation is communicated through the transparency explanation, not through a two-number spread on the hero stat itself.
  - **Transparency, two touchpoints**: a small (i) icon directly on the calorie stat opens a short explanation ("Estimated using your logged sets and body weight, based on standard exercise-science averages for resistance training. Actual calories burned vary by person and effort."); a fuller version of the same explanation, including the tier table above, lives in Profile next to the bodyweight field for anyone who wants the full picture.
  - This deliberately does not account for which specific exercises were done or how much weight was lifted beyond the set-count tiering — a more dynamic, per-exercise calculation was considered and explicitly deferred as too complex for V1. The set-count MET tiering is a reasonable middle ground: simple to build and explain, while still responding to how much work was actually logged rather than being a flat constant for every session.

## Set logging by `loadType`

Every exercise carries a `loadType` that determines what a set consists of. **Four types, and every numeric input in the app is an unsigned positive number** — the sign, where one exists, is carried by the type, never typed by the user.

| `loadType` | Count | Required field | Optional field | Set row |
|---|---|---|---|---|
| `weighted` | 196 | `weightKg` + `reps` | — | `[ 22 ] kg  ×  [ 10 ] reps  ✓` |
| `bodyweight` | 47 | `reps` | `addedKg` (positive) | `[ 12 ] reps  ⊕ add weight  ✓` |
| `assisted` | 3 | `reps` | `assistKg` (positive) | `[ 20 ] kg assist  ×  [ 8 ] reps  ✓` |
| `timed` | 14 | `durationSec` | `weightKg` (positive) | `[ 0:45 ]  ⊕ add weight  ✓` |

Storage note: `assistKg` is stored as its own positive field, **not** as a negative `addedKg`. `bodyweight` and `assisted` are separate exercises with separate histories, so nothing is gained by making them share a signed column, and a signed column invites a user to book a `+30kg` PB on an assist machine.

### Rules common to all four types

- **A set is complete when the user taps its checkmark and its required field is > 0.** Tapping the checkmark with an empty required field focuses that field instead of completing the set. Optional fields never gate completion.
- **This is the definition the streak and the calorie tier both consume** — a 45-second plank set and a heavy squat set each count as exactly one set. Crude by design; the calorie model is already a coarse set-count proxy.
- **Prefill from history.** The first set of an exercise prefills from the same set index in the user's last session of that exercise; each subsequent set added prefills from the previous set in the current session. Prefilled values render in `#6B6156` (muted) until touched or confirmed, so the user can tell what they typed from what the app guessed.
- **Optional weight is a collapsed chip, not a visible field.** It expands on tap. Users who never add weight to a push-up never see an input they have to skip past.
- **No capability flags.** The optional weight field is offered on every `bodyweight` and `timed` exercise. Auditing 61 exercises to hide a chip nobody would notice is not worth it.
- Each set row supports delete (swipe or long-press). Removing a set recomputes everything derived.

### Duration input (`timed` only)

Numeric seconds field with quick-fill chips (`30s` `45s` `60s` `90s`), displayed as `m:ss` above 60 seconds. **No live stopwatch in V1** — it is a running-timer component with lifecycle and background concerns, for 14 exercises.

### Display formatting

One formatter per type, used identically on the log screen, session detail, history rows, and the "Last time" hint.

| Type | Condition | Format | Example |
|---|---|---|---|
| `weighted` | always | `{kg}kg × {reps}` | `22kg × 10` |
| `bodyweight` | no added weight | `{reps} reps` | `12 reps` |
| `bodyweight` | added weight | `+{kg}kg × {reps}` | `+10kg × 8` |
| `assisted` | always | `{kg}kg assist × {reps}` | `20kg assist × 8` |
| `timed` | no weight | `{m:ss}` | `0:45` |
| `timed` | weight | `{kg}kg × {m:ss}` | `24kg × 0:45` |

### Personal best per type

Applies both to the PB shown on Exercise Detail and to the per-session PB count described under Progress tracking.

PB is the max of the set's progression metric, compared lexicographically, ties broken by earliest date. Completed sets only.

| Type | Metric | Note |
|---|---|---|
| `weighted` | `(weightKg, reps)` | |
| `bodyweight` | `(addedKg, reps)` | Degenerates to max reps when nobody ever adds weight — no special case needed. |
| `assisted` | `(-assistKg, reps)` | **Inverted: less assistance is better.** The one place where a smaller number is the record. |
| `timed` | `(weightKg, durationSec)` | |

### Editing and deleting

The app remembers everything on the user's behalf, so it must also let them correct it. Three distinct actions, three distinct places:

| Action | Where | Behaviour |
|---|---|---|
| **Discard** | Active session — secondary button beside Finish | Confirmation dialog, then session and all sets are dropped |
| **Delete workout** | Profile → session detail, and/or swipe on a history row | Confirmation dialog, then permanent removal |
| **Edit** | The workout card — live during a session, or opened from Profile history | Inline edits, saved immediately |

- **Deletion is a hard delete.** No `deletedAt` tombstone in V1. Cloud sync is a V2 parking-lot item; if it is ever built, tombstones will need to be introduced then.
- **The workout card is one component in two modes.** Session detail *is* the logging screen pointed at a past session — same layout, same edit affordances. Do not build a separate read-only viewer that will drift from the live version.
- **What is editable on a saved session:** the title, `performedOn`, the weight and reps of any set, adding or removing sets, and removing an exercise.
- **Editing `performedOn` on a past session is supported**, which is what makes the Profile streak copy — *"logged a session for an earlier date? your streak updates to match"* — true for corrections as well as for new sessions.
- All aggregates recompute on read after any edit or deletion — see "Derived values" above.

### Navigation and shell

- **Three tabs: Workout · Muscles · History.** Plain over clever, for a beginner audience. "Muscles" rather than "Muscle groups" — shorter, same meaning. **Profile is a header avatar on the three tab roots, not a tab**, and **the tab bar appears only at L0** — pushing any screen hides it. History is promoted to a tab because it is the most-revisited surface in the app. Rationale and the architecture this rests on: `docs/adr/0003-l0-navigation-variant-a.md`.
- **Splash screen is branding only and must never block.** The app is offline with no login and nothing to fetch, so there is nothing legitimate to wait for. Target roughly 600ms and never gate entry on it.

### Beginner experience
- Muscle groups and sub-muscle groups are visible and explained, not hidden behind jargon.
- Each workout template has a short explanation of what it means and who it's for.
- The Workout Overview screen shows which muscles and sub-muscles are targeted before the user starts logging, regardless of whether the session came from a template or ad-hoc search.

### UX principles
- Maximum 3 taps to start a workout.
- Minimal typing — steppers/number inputs over free text wherever possible.
- Fast screens, no unnecessary popups.
- Works fully offline.

---

## V1 technical scope

- Local storage only.
- No login or signup.
- No cloud backup.
- No rest timer (parked for a later version).
- No workout duration tracking. Since some users log live during a workout and others log retrospectively (catching up later, or logging from memory), any duration the app calculated could be meaningless or actively misleading — especially since it would show up on the shareable summary card. Exercise count is used instead of duration wherever a stat is needed, since it's accurate regardless of when logging happened.
- No notifications.
- No wearable integration.
- No AI.
- No premium plan.
- No ads.

## V1 success metrics

Not downloads. Not revenue. Success means:

- ✅ Published on the Play Store.
- ✅ First stranger installs it.
- ✅ First workout logged.
- ✅ First review received.
- ✅ First feature request received.
- ✅ One update shipped after launch.

## V2 parking lot (not now)

- Google login
- Cloud sync
- iOS app
- Rest timer
- AI workout suggestions
- AI form analysis
- Exercise videos
- Nutrition tracking
- Meal plans
- Wearable integration
- Apple Health / Google Fit
- Friends
- Leaderboards
- Workout sharing
- Smart workout recommendations
- Adaptive workout plans
- Home workouts
- Coach mode
- Gym trainer mode
- Premium features

---

## Visual theme — Coral

A single dark, warm palette. One hue family throughout (coral/orange), so there's no risk of competing accent colors — the muscle map's "worked" color and the app's action color are literally the same color, at different intensities. This also matches the near-universal convention of muscle heat-maps being red/orange, so the core visual (muscles lighting up as they're worked) reads instantly without the user needing to learn a color code.

### Palette

| Role | Value | Usage |
|---|---|---|
| Page background | `#17140F` | App background, base layer |
| Card / elevated surface | `#211D18` | Cards, list rows, input backgrounds |
| Border / divider | `#332C22` | Hairline separators, outlines |
| Muted surface (unfilled regions) | `#241F19` | Muscle map regions not yet logged, disabled states |
| Text primary | `#F5EFE8` | Headings, primary content |
| Text secondary | `#A89C8E` | Subtitles, supporting text |
| Text muted | `#6B6156` | Placeholder text, "not started" labels |
| Accent — strong | `#D85A30` | Primary buttons, primary muscle fill, active nav tab, checkmarks/done states |
| Accent — light | `#F0997B` | Secondary muscle fill, lighter emphasis, less prominent accents |
| Text on accent fill | `#1B0C05` | Text/icon color when placed on top of a strong-accent-filled background (e.g. button label) |
| Destructive | `#C4553A` | Delete a workout, discard a session. Nothing else. |

### Usage rules

- **Accent strong (`#D85A30`)** is the "this is active / this has been worked" color — used consistently for primary buttons, the active tab bar icon, primary muscle-map fill, and completion checkmarks. Same meaning wherever it appears.
- **Accent light (`#F0997B`)** is reserved for secondary muscle indication and lower-emphasis accents — never used for primary actions.
- **Destructive (`#C4553A`)** is for destructive actions only — delete a workout, discard a session. It exists because accent strong could not carry it: accent strong means "active / this has been worked", so a delete confirmation painted in it reads as approval. Never a primary action, never a fill behind body text. Sessions are deletable, so this surface is real, not hypothetical.
- Everything else (body text, borders, unfilled states, secondary buttons) stays neutral gray/off-white. No other colors are introduced — this keeps the palette calm and prevents visual competition on screens that combine the muscle map with buttons or list states.
- Because it's a single hue family, new screens can freely reuse the same two accent values without needing to re-derive a color rule each time — unlike a two-color brand system, there's no governance overhead to maintain as the app grows.
