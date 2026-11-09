---
name: turtle-qa
description: End-to-end QA pass for TurtleLift. Runs static checks, the unit and widget suite, the generated-data validators, the Flutter integration tests and the Maestro user-story flows on two iOS simulators, plus the taste screenshots at normal and largest text size. Then reports a pass/fail table per user story and every bug with repro steps. Use when asked to "QA", "test everything", "make sure it has no bugs", run the Maestro flows, or check a branch before review.
---

# turtle-qa

One command runs it all: `tool/qa.sh`. This file says what each step proves,
how to read a failure, and how to report.

## 0. What outranks this skill

`CLAUDE.md` and `docs/00-build-spec.md` (with `01`–`04` over `00`). In
particular: closed palette, pinned `AppScreen`, nothing stored that can be
derived, exercise and food copy never edited, nothing out of scope. **No
commits, no pushes, no `git stash`** unless the user asks. Never run
`dart format` over `lib/` or `test/` wholesale.

A failing test is a question: is the test wrong, or is the app? **Never make a
test pass by weakening it.** For an app bug, work test-first: keep or write a
test that fails for the bug, fix the app minimally, then watch it pass.

## 1. Setup (once per machine)

- Flutter on PATH, Xcode with iOS simulators **iPhone 17e** and **iPhone 17
  Pro Max** (any two names work with `DEVICES=`). Do not use a simulator the
  user is reviewing a build on.
- Maestro CLI: `curl -fsSL https://get.maestro.mobile.dev | bash`, which
  installs to `~/.maestro/bin`. Needs Java 17. The scripts add it to PATH.
- If `sqlite3`'s native build hook cannot download its prebuilt library (504
  or hash mismatch), copy `.dart_tool/hooks_runner/shared/sqlite3/build/download-*/`
  from a checkout that has it, and check the hashes.

## 2. What runs, in order

```sh
tool/qa.sh                       # everything, both simulators (about 40 min)
tool/qa.sh --fast                # steps a-e only, no simulator
SKIP="taste" tool/qa.sh          # skip steps by name
DEVICES="iPhone 17e" tool/qa.sh  # one device
```

| Step | Command | Proves |
|---|---|---|
| a `analyze` | `flutter analyze` | no analyzer issues |
| b `test` | `flutter test` | about 1210 unit and widget tests, including the `test/qa_*` files |
| b2 `test-tz` | `TZ=America/New_York flutter test` | the same suite in a zone with daylight saving, where a local day is 23 or 25 hours twice a year (`qa_dst_label_test.dart` only bites there) |
| c `generated` | the CI generated-data job: taxonomy and body-path generators, exercise validator, food unittest and validator, then `git diff --exit-code -- assets` | shipped data regenerates byte for byte |
| d `sync` | `tool/sync_generated.sh --check` | `lib/src/data/generated/` matches `assets/` |
| e `drift` | `dart run build_runner build` + diff of `app_database.g.dart` | Drift codegen is current |
| f `integration` | `flutter drive` of every `integration_test/*_test.dart` except taste shots, per device | the real `main()` on a device, with the debug sample seed: `workout_flow_test`, `sweep_test` (fails on any framework error while walking every screen) |
| g `maestro` | `tool/maestro_run.sh <udids>` | the user stories below, through the accessibility tree the way a person (and VoiceOver) drives the app |
| h `taste` | `tool/taste_shots.sh`, then a second run on the first device at `accessibility-extra-extra-extra-large` | about 38 screens on a small and a large phone, and at the 1.3x text clamp |

Logs: `build/qa/<step>.log`, summary in `build/qa/summary.txt`.

## 3. The Maestro flows (`.maestro/`)

`tool/maestro_run.sh` builds a debug simulator app with
`--dart-define=TURTLE_NO_SEED=true` (so a debug install starts **empty**; the
sample seed would fill History and Diet), reinstalls it, and runs every
`.maestro/flows/*.yaml` with `launchApp: clearState: true`. Output per device
goes to `build/maestro/<device>/`: `junit.xml`, `report.html`, failure
`artifacts/`, `app.log` (the app's log stream) and `app-exceptions.txt` if
Flutter logged an exception. An exception fails the run even when every flow
passed.

| Flow | User story |
|---|---|
| 01 | Log a full workout: weighted, bodyweight, assisted (with its banner), timed; mark done; finish; summary numbers; History row and card; Muscles renders |
| 02 | Edit a past workout from History (set value, remove a set), derived figures follow; delete with Cancel then Delete |
| 03 | Ready-made template preview, Cancel, start, discard; Save as template; start it from My templates; duplicate, rename, delete on Profile |
| 04 | Personal details: gender, bodyweight, keypad dismiss, persistence, kcal appears |
| 05 | Schedule: training days, Remind me, explain-first sheet, iOS prompt, persistence after kill |
| 06 | Diet: first-time state, target from suggestion, picker filters and search, serving sheet, Repeat on, eaten tick, edit servings, remove and undo, meal reminders screen, persistence after kill |
| 07 | Reminder tap deep link: a diet reminder, warm (pops a pushed screen) and cold, opens Profile › Diet; a training reminder opens the Workout tab (ADR 0008). Scripted: `.maestro/scripts/07_reminder_deep_link.sh` |
| 08 | Export: disabled with reason when empty; share sheet; dismissed status line |
| 09 | Delete all data: Cancel, then confirm; every tab empty; no re-seed on relaunch |
| 10 | Home and kill mid-workout keep the session |
| 11 | Upgrade from the last published build (schema 5): every record survives, the open workout resumes, v6/v7 migrations run, Diet starts empty, export counts the old workouts. Scripted: `.maestro/scripts/11_upgrade_from_v5.sh` copies `test/fixtures/schema_v5_from_5fcae5f.sqlite` into the installed app's Documents first |
| 12 | Workout tab (ADR 0008): week strip and last-workout line on the landing, Recent in the picker, last time in each set row (tap to copy), pinned Mark exercise done, live PB mark, PB in the kcal slot, Share card, Do again from History |
| 13 | Template from scratch (ADR 0009): New template tile, multi-pick, arrows, save, Edit template from the preview, start, Edit list (move, remove) |
| 14 | Custom exercise (ADR 0009): create from the picker, straight to logging, History, its no-form-guide page, into a template, Export counts it |
| 15 | Swap in place (ADR 0011): Edit list swaps an untouched exercise at its position; one with a logged set is refused with a one-line reason and Add instead |
| 16 | Exercise note (ADR 0011): note in set logging, shown in History detail, `Last time: …` hint next workout |

**The v5 fixture** was written by commit 5fcae5f's own stores (a throwaway
worktree at that commit), so it is exactly what a user's device holds. The
same file is opened directly by `test/qa_upgrade_from_v5_test.dart`. When a
schema step ships, make a new fixture from the then-published commit the same
way rather than editing this one. A real old-binary-over-new install was
done once by hand (QA second pass); the scripted flow is its regression.

**Accessibility rule (enforced by `test/qa_semantics_tap_test.dart`).** A
`Semantics(button: true, excludeSemantics: true)` must also carry
`container: true` and `onTap:` (the GestureDetector's callback): without
`onTap` the node is a button with no action for VoiceOver or TalkBack, and
without `container` it merges with the text beside it. A merged label in a
Maestro hierarchy dump (`"A\nB"` where A is a button) is the symptom.

**Selectors.** Text is matched by accessibility label (a full-string regex,
case-insensitive, so `"Paneer.*"` also matches a search field holding
"paneer": use the full row label). Where labels collide, the app carries a
`Semantics(identifier:)`, which iOS exposes as the accessibility id:
`set-<n>-weight|reps|assist|duration|added|add-weight|check`,
`bodyweight-field`, `record-weight`. Add one only where a label cannot do it.

**Simulator quirks the flows already handle:**
- An element under the floating tab bar counts as visible to Maestro, and a tap
  on it hits the bar. Scroll with `centerElement: true` before tapping (see
  `subflows/finish_workout.yaml`).
- The number pad has no return key. Tap off the field to dismiss it (the app
  does this on tap-outside; `subflows/type_into.yaml`).
- `clearState` revokes notification permission, and `launchApp: permissions`
  does not grant it on iOS 26. Grant it through the app's own opt-in. Maestro's
  driver can accept the system alert by itself, so the Allow tap is optional
  and the proof is the switch staying on.
- Notification banners are not in the accessibility tree, and a tap on Notification
  Center does not open the app. Flow 07 has `push_server.py` deliver a
  `simctl push` at the moment the flow asks (`http.post`), then taps the
  banner by position. The payload carries the plugin's own keys
  (`NotificationId`, `presentAlert`/`Sound`/`Badge`, `payload: diet/today`),
  so the plugin routes the tap as it would a real reminder.
- Percent coordinates must be whole numbers (`"30%"`, not `"29.5%"`).

**Debugging a flow.** `maestro --device <udid> hierarchy` dumps what Maestro
sees. `maestro --device <udid> test .maestro/flows/06_diet_plan.yaml` runs one
flow. `FLOWS="06 07" NO_BUILD=1 tool/maestro_run.sh <udid>` reruns a subset.

## 4. Exploratory pass (after the scripted steps)

Drive the app by hand on both simulators for what scripts do not assert:
- Screenshots: `xcrun simctl io <udid> screenshot out.png`. Read them.
- Volume: a 300-session database can be generated with the stores in a
  throwaway test and pushed into the app's Documents
  (`xcrun simctl get_app_container <udid> dev.indresh.turtleLift data`).
- Wrong numbers: every figure is derived. Check a summary, a History card and a
  Diet day against hand arithmetic (`docs/00` §7, §8, ADR 0007 rounding).
- Stale state: edit or delete something, then visit every screen that shows it.
- Clipped text and overflow at the large text size (the taste run).
- Exceptions: `build/maestro/<device>/app.log`, or
  `xcrun simctl spawn <udid> log stream --predicate 'process == "Runner"'`.

## 5. Not testable on a simulator (say so in the report)

- A scheduled local notification firing at its real time (the simulator clock
  cannot be moved). The tap routing is covered by flow 07, and the schedule
  contents by the reminder unit tests.
- The date cannot be changed on a simulator. Midnight, week rollover and
  streak decay are covered by injected-clock tests (`test/qa_date_boundary_test.dart`,
  `derived_test.dart`, `diet_derived_test.dart`).
- Android: these scripts are iOS-only. CI builds the APK. Every semantics
  button now names its tap action (unit-tested), but TalkBack itself has not
  been run.
- Real share targets (Mail, Files): the share sheet opens and dismisses.

## 6. Report

1. Tooling and versions (Flutter, Xcode, Maestro, simulators).
2. Step table from `build/qa/summary.txt`.
3. **Per user story, per device:** a table of flows 01 to 10 (07 warm and cold)
   by iPhone 17e and Pro Max, PASS or FAIL.
4. **Every bug:** symptom, repro steps (device, flow or manual steps), root
   cause, fix, regression test file. Separate bugs fixed from bugs left for the
   user (product calls, or anything needing a spec change).
5. What was not testable and why (section 5).
6. Test counts: `flutter test` total, integration tests, Maestro flows (12 flows, 14 cases per device: 07 has warm, cold and training).
