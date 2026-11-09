# Workout tab gaps: progress (resumable)

Worktree: `.claude/worktrees/agent-a207fccb24d12dbf3`, detached at `origin/taste-pass-production-polish` (b2543d1). Nothing committed.

## Done
- Schema v8: `CustomExercises` table (`app_database.dart`, `.g.dart` regenerated), migration step `from < 8`, tests in `test/app_database_migration_test.dart` (7 -> 8 group, v7 fixture builder).
- Data: `lib/src/data/custom_exercises.dart` (store, draft validation, `CustomExerciseList` notifier, `custom-` id prefix, delete blocked when logged, load type locked when logged, delete strips from templates). `Exercise.isCustom` (additive).
- One merged index: `libraryIndexProvider` (boot override in `main.dart`) + `exerciseIndexProvider` = library + custom.
- Export (`exercises` section) and Delete all data cover custom exercises; Data screens count them.
- `CustomTemplateList.update` (rename + exercises + order), `forgetExercise`.
- Live session: `ActiveSession.moveExercise` / `SessionStore.reorderExercises`. Bug fixed: `addExercise` position after a removal could collide (regression test).
- UI: `editor_parts.dart`, `custom_exercise_screens.dart` (editor, custom detail page with plain no-form-guide note, My exercises), `template_editor_screen.dart` (name, multi-pick, arrows to reorder, remove, delete, unsaved-changes guard), picker multi-select + Create exercise row + Your exercises group + search by muscle/equipment, `pushExerciseDetail` routes custom to its own page, first-time gate skipped for custom.
- Library: Yours first, New template, row tap -> editor, My exercises row. Landing: My templates rail always shown with New template tile; rail no longer a lazy ListView (a11y bug). Preview sheet: Edit template on custom templates.
- Tests green so far: custom_exercises_test, template_editing_data_test, migration, picker, library, workout_root.

- Live session "Edit list" mode (arrows + remove, a11y buttons) in `session_overview_body.dart`.
- Widget tests `test/workout_gaps_ui_test.dart` (12). Updated tests whose rules changed (library/landing/upgrade/wipe).
- `flutter analyze` clean; `flutter test` 1331 passing.

- Audit doc, ADR 0009, docs 00/02 + CLAUDE.md updated.
- Maestro flows 13, 14 written. iPhone 17e is shared with another agent's run, so a private clone simulator `TurtleLift gaps 17e` (A57CE4A8-D25B-4057-A128-C40A6E766CDC) is used.

- Fixed: template workout's first pick after Start logging was dropped (ready block unmounted); keyboard over Save after picker.
- Flows 03, 13, 14 passed on the clone 17e; final rerun of 01 03 12 13 14 in progress.

- Final: Maestro 01, 03, 12, 13, 14 PASS on the clone 17e (A57CE4A8), no app exceptions. `flutter analyze` clean, `flutter test` 1332 passing.
- Seeded debug build installed and launched on the iPhone 17 review device. Screenshots in the session scratchpad `workout-gaps/`.

## Not done (left for later or the user)
- Full `tool/qa.sh` (skipped on instruction), Pro Max runs, taste screenshots at the largest text size, integration tests.
- A new upgrade fixture from the then-published commit (the v5 fixture still runs and now reaches schema 8).
- Decisions listed in the audit: notes, kg/lb, warm-up sets, supersets, swap in place.
