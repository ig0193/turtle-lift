# Profile split — session notes and decisions

**Date:** 2026-09-15 (work began 2026-09-14 evening)
**Plan:** `docs/plans/2026-09-14-2324-feat-profile-split-plan.md`
**Branch:** `feat/tab-one` · **nothing committed or pushed** — every change below is uncommitted in the working tree.

This records the decisions taken while building, especially the ones taken autonomously. The *product* decisions live in the plan as KD1–KD5 and KTD1–KTD7 and in `docs/adr/0003`; this file covers what changed during execution and why.

---

## Decisions that changed the plan

### 1. The migration takes schema version 3, not 2

**Found mid-build:** a second plan appeared in the repo — `docs/plans/2026-09-14-2351-feat-workout-session-flow-plan.md`, written at 23:51 while U1 was being implemented, with `.scratch/workout-flow/` tickets beside it. Another session is working here.

It collides directly. Its R1 claims "at schema version 2" — the version this work had just migrated to — and its own verification line reads *"the Profile plan no longer claims schema version 2"*, so that session had already decided its work takes 2 and this one should move.

**Decision (user-directed):** the session work keeps version 2; this work moved to 3. Cheapest resolution available — one uncommitted migration step, nothing depending on it yet, versus moving a larger plan that had already been written around version 2.

**Consequence worth knowing:** the guard is `if (from < 3)`, not `if (from == 2)`. Version 2 does not exist yet, so a user upgrading today arrives straight from 1 and must still get these tables. When the session step lands it adds its own `from < 2` branch beside this one and a 1 → 3 upgrade runs both in order. Keying on an exact version would silently skip this step for exactly the users who have it.

**Still open:** if a build carrying version 3 ships to a real user *before* the session work lands, that user is already at 3 and the later `from < 2` branch will never fire for them — they would never get the session tables. Nothing has shipped, so this is currently theoretical, but the two pieces of work should land together or in order.

### 2. Bodyweight entries are immutable, with no backdating at all

The review found a contradiction: the plan promised a weight change never moves a past session's calorie figure, while also shipping edit, delete, and backdating — each of which moves past figures on the next view, reproducing the exact bug the work exists to fix.

**Decision (user-directed):** strictly append-only. No edit, no delete, no backdating. A correction is a new entry that supersedes the old one going forward.

**Tightened beyond what was asked, deliberately:** the option chosen said "no backdating below the earliest entry". That still leaves a hole — an entry dated *between* two existing ones changes resolution for every session in that window. The only version that delivers the invariant is **entries take effect from the day they are recorded**, so that is what was built. Flagged at the time rather than done silently.

This is now KD5 in the plan, and it removed a whole control: there is no date picker on the personal-details screen, because there is no legal way to pick a date other than today.

### 3. The never-changes invariant is narrower than first written

The plan's property test originally read "no sequence of legal writes can change what an already-resolved past date returns". That is false, and usefully so — recording a weight today legitimately changes what *next month* resolves to, and no session can exist on a day that has not happened.

The true invariant, now encoded in `test/bodyweight_resolution_test.dart` and corrected in the plan: **a date is frozen once a weigh-in later than it exists.** It still kills a naive "use the current weight" implementation, which was confirmed by writing that implementation and watching the guards fail.

---

## Findings raised during review, and how they were settled

Six reviewers ran against the plan before any code was written. Seven corrections were applied to the plan itself; the substantive ones:

- **The plan overclaimed what it proves.** `Session`, `SessionExercise`, `SetEntry` and `caloriesFor` do not exist anywhere in `lib/` — verified by grep, twice, by different agents. The Success Criteria and Verification Contract now say the invariant is proven at the function level only, and that the user-observable guarantee stays unproven until the deferred wiring lands. **Do not read a green suite as the motivating calorie bug being closed.**
- **`TemplateRow` cannot carry two actions.** It wraps the whole row in one `GestureDetector` under a single `onTap`. The plan originally said to reuse it for rename-and-delete rows, which is structurally impossible; it now specifies a new row type with a trailing actions slot.
- **Two reported "spec conflicts" dissolved.** `loggedAt` "never shown" versus its use as a sort key is a misreading — using a field to order by is not displaying it. The "set count is the headline stat" line in `docs/00` is a wording slip: `docs/01:220` says "headline *volume proxy*", meaning it stands in for the banned kg figure, not that it renders largest. `docs/00` has been corrected rather than the rule changed.

---

## Judgement calls taken during implementation

These were left to implementation deliberately, or arose while building. None needed a product decision.

| Call | Where | Why |
|---|---|---|
| Bodyweight date stored as `YYYY-MM-DD` **text**, not `DateTimeColumn` | `app_database.dart` | A calendar date is not a timestamp. Drift's default round-trips through UTC and would move an 11pm entry to the next day. Text in ISO order also sorts and compares correctly, which is all resolution needs. |
| `date` is the table's primary key | `app_database.dart` | Gives "one entry per day, a second replaces it" for free, with no application-level guard to forget. |
| Custom template group ids stored comma-joined, not as a child table | `app_database.dart` | The app never queries templates *by* group; it loads the whole template and renders it. A join table buys nothing for a list read whole and at most twelve short ids long. |
| `customTemplatesProvider` stayed a plain `Provider`, delegating to a new `customTemplateListProvider` notifier | `custom_templates.dart` | Forced, not stylistic: Riverpod 3.4.3 defines `overrideWithValue` only on `Provider`/`Future`/`Stream`, never on `NotifierProvider`, and `workout_root_test.dart` overrides that name by value. The split preserved the existing read contract — that test passed completely unmodified, which was the proof. |
| Custom templates ordered by name, then id | `custom_templates.dart` | The table has no insertion-order column and this work was not to add one. The order after a write must match the order the next launch reads back, or the list quietly reshuffles on restart. |
| Tests override `initialBodyGenderProvider`, not `bodyGenderProvider` | `body_gender.dart`, `body_diagram_test.dart` | Same Riverpod constraint. This is the stronger seam anyway — it exercises the shipped wiring rather than stubbing past the notifier. One line of an existing test changed; all 21 gender call-site tests passed unmodified. |
| `weightInEffectOn` is a pure function plus a thin provider wrapper, not a `Provider.family` keyed on date | `bodyweight_resolution.dart` | The caller is a history or summary screen walking many sessions, which would mean an unbounded set of cached providers each holding a subscription for one list scan. |
| The profile screen's four destinations sit behind injectable `Provider<WidgetBuilder>` seams | `profile_screen.dart` | Let the screen be built and fully tested before its destinations existed, and let two screens be built in parallel without touching each other's files. |

---

## Two things found that are not this work's to fix

**`DividerRow` drops its tap action from the accessibility tree.** It wraps its `GestureDetector` in `Semantics(excludeSemantics: true)`, which discards the detector's tap action along with its children's labels. Every divider row in the app — `SubGroupRow`, the exercise and search rows, and now the profile rows — announces as a button a screen reader cannot activate. `TemplateRow` has the same shape and likely the same problem. The profile screen's semantics test pins what is true today with a comment saying why, rather than quietly asserting less than it means. **The fix belongs in `divider_row.dart`.**

**`prototypes/screens.html` screen 4 is stale.** It still renders the three-stat grid (Day streak / Workouts / Sets) and the history list that ADR 0003 moved to the History tab. The repo rule is that prototypes lead the docs on layout — but not on *where a figure lives*, which is a product rule, so `docs/04` won. Reported rather than silently resolved, per `CLAUDE.md`.

---

## What is deliberately not built

- **The History tab's own layout.** Six ranked candidate variants are in `docs/ideation/2026-09-14-history-tab-l0-ideation.html` with an interactive prototype at `prototypes/history-tab-variants.html`; none is chosen. This work only establishes that derived figures belong there.
- **Promoting a past session into a template.** Needs an explicit amendment to the only-place-authored rule at `docs/04:20` and `docs/00:240`.
- **Creating a template from scratch** by muscle-group multi-select, and changing which groups a custom template contains. Deferred per KD4 — a duplicate currently differs from its original only in name.
- **Wiring `caloriesFor` to real sessions.** Blocked on the session tables, which do not exist.
- **Export and delete-all.** Named as rows on the profile destination; the destinations behind them are placeholders.

---

## Final state

All nine implementation units are complete. **390 tests pass** (up from 272 at the start), `flutter analyze` is clean, and the app builds and runs on an iOS simulator. **Nothing is committed or pushed** — every change is uncommitted in the working tree on `feat/tab-one`.

| Unit | What landed |
|---|---|
| U1 | Schema version 3 and the repo's first `MigrationStrategy`: bodyweight entries, custom templates, a gender column. 9 tests against a real v1 database on disk. |
| U2 | `PersonalDetailsStore` and the three-layer provider shape; `bodyGenderProvider` reads stored state. 31 tests. |
| U3 | `weightInEffectOn`, pure and unwired, with a property test proving no legal write moves a frozen date. 17 tests. |
| U4 | Custom templates moved from a hardcoded empty list to Drift. 27 tests. |
| U5 | The avatar destination: four rows, two groups, no derived figures, behind injectable navigation seams. 15 tests. |
| U6 | The template library: duplicate, rename, delete; predefined rows immutable. 28 tests (shared with U7's file run). |
| U7 | Personal details: gender choice, read-only weight log, no date picker, calorie explainer. |
| U8 | The two discovery routes — a labelled avatar and a Workout-tab row visible at zero custom templates. |
| U9 | ADR 0003, `docs/00` and `docs/04` amended. |

### Verified on the simulator

Captured on a booted iPhone 17: the Workout tab showing the labelled **Profile** avatar and the always-visible **Manage templates** row; the Profile destination with its four rows and no stats; the Personal details screen; a real bodyweight recorded end to end (**78.5 kg, from 2026-09-15**) with the row carrying no edit or delete affordance; and the template library listing all eleven predefined templates with a duplicate action and nothing else.

Duplicate, rename and delete were **not** driven by hand on the simulator — macOS click automation proved too unreliable on small targets. They are covered by widget tests that exercise the real flows against an in-memory database, which is stronger evidence than a screenshot.

A throwaway `lib/preview_main.dart` was used to boot directly into those screens for the screenshots, and has been deleted.

### Before this ships

- **Land the session-flow work's schema step 2 before or with this.** A build carrying version 3 installed ahead of it would leave that user permanently past the `from < 2` branch.
- **CI will regenerate `app_database.g.dart`** and fail on a diff if it is not committed alongside the schema change. It is written to disk and staged-ready.
- The three review items left open: annotating the two calorie requirements as display-deferred, and the two P2 judgement calls that were taken during implementation (avatar label placement, duplicate naming) if either wants revisiting.
