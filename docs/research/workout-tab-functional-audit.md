# Workout tab: functional audit

Date: 2026-11-09. Build: `origin/taste-pass-production-polish` (b2543d1), debug,
unseeded, iPhone 17e simulator, driven with Maestro plus a code read of every
Workout-tab screen. Benchmark: what a serious strength logger lets you do
(Strong, Hevy and similar). Result of each gap: **built** in this pass, **needs a
decision** from the user, or **out of scope** (`CLAUDE.md`, `docs/00` §13).

## Journeys driven

| Journey | Works | Missing / off |
|---|---|---|
| New user: landing → ready-made preview → start → ready view → Start logging → picker → first-time Exercise Detail gate → logging → finish | Yes, end to end | Picker search said "Search exercises, muscles, equipment" but matched names only ("chest" found nothing). A search with no match was a dead end. |
| Make my own template | Only by finishing a workout and tapping Save as template, or duplicating a ready-made one | **No way to build one from scratch.** No way to change a template's exercises or their order: a duplicate differed from its original only by name. Library rows were not tappable. Library listed the 11 ready-made first and buried "Yours" (and its only hint) a screen and a half down. |
| Start from my template | Preview + start work | The **My templates rail tiles were missing from the iOS accessibility tree** (lazy horizontal `ListView`): VoiceOver could not reach them, and Maestro flow 03 only passed because `"QA bench.*"` matched the snackbar text. No Edit from the preview. |
| My machine is not in the library | — | **No custom exercises at all.** A user with a gym-specific machine could not log it. |
| Live session: change the plan | Add (picker), remove (swipe or long-press only) | **No reorder.** Remove had no visible control and no VoiceOver action. |
| Template workout: Start logging → pick an exercise | Picker opens | **Bug (found driving the build):** on a workout with a plan, the ready view that opened the picker is replaced by the list as soon as logging starts, and the pick was handed back to its unmounted context: nothing opened, nothing was added. Every template start's first pick was silently dropped. |
| Live session: add after removing | Looked fine | **Bug:** `addExercise` used the row count as the new position, so after a removal a new row could share a position with an existing one and the list order was undefined. |
| Returning user: History → edit sets / Do again / Save as template | Yes | — |
| Per-exercise history, last time in each set row, PB mark | Yes | — |

## Gaps, ranked by user impact

| # | Gap | Decision | Why |
|---|---|---|---|
| 1 | Build a template from scratch (name, pick exercises, order) | **Built** | The user's headline complaint; every serious logger has it. |
| 2 | Edit a custom template's exercises and order; delete from the editor | **Built** | Without it a template is frozen at birth. |
| 3 | Custom exercises (name, equipment, load type, primary + secondary muscles) usable everywhere | **Built** (ADR 0009, schema v8) | Library has 260; every gym has a machine it lacks. |
| 4 | Custom exercises in templates and sessions | **Built** | Falls out of one merged index. |
| 5 | Reorder / remove in a live session, accessibly | **Built** (Edit list mode, arrows) | Order matters when a machine is taken. |
| 6 | Rail tiles unreachable by VoiceOver | **Fixed** | Accessibility bug. |
| 7 | Position collision after remove + add | **Fixed** (regression test) | Data bug. |
| 7b | First pick after Start logging dropped on a template workout | **Fixed** (regression test) | Broke the main template path. |
| 7c | Keyboard came back over the editor's pinned Save after closing the picker | **Fixed** (unfocus; tap-outside dismisses) | Found by Maestro. |
| 8 | Picker search ignores muscles and equipment; no-match dead end | **Fixed**: matches muscle and equipment; Create row | Copy promised it. |
| 9 | Library buries the user's own templates | **Fixed**: Yours first, New template, rows open the editor, My exercises row | Findability. |
| 10 | Notes per session / per exercise | **Needs decision** | New stored free text on three screens and in export; small but a product call. |
| 11 | kg / lb unit | **Needs decision** | Every input, formatter, PB and export changes; app is kg-only by spec. |
| 12 | Warm-up set marking | **Needs decision** | Changes what counts as a completed set, which drives streak, set count, kcal tier and PBs. |
| 13 | Supersets | **Needs decision** | New grouping concept on the session model; not in the docs. |
| 14 | Swap an exercise in place (substitute) | **Needs decision** | `docs/02` lists it as not built; remove + add covers it today. |
| 15 | Reorder exercises inside a saved workout | Not built | Order of a finished workout carries no meaning anything derives from. |
| 16 | Rest timer | **Out of scope** | `CLAUDE.md`. |
| 17 | Stored workout duration | **Out of scope** | `CLAUDE.md`; live clock is display-only. |
| 18 | Routines / multi-day programmes | **Out of scope** | No multi-day splits. |
| 19 | AI suggestions, wearables, badges | **Out of scope** | `CLAUDE.md`. |

Already present and checked: edit sets after finishing (History detail is the
summary component), per-exercise history (See all N sessions), template from a
past session (Save as template on any History detail), Do again.

## What shipped

See `docs/adr/0009-custom-exercises-and-template-editing.md` for the decisions and
`docs/research/workout-tab-progress.md` for the file list.
