# Combine progress — Workout gaps (A) + Exercise demonstrations (B)

Base: b2543d1 (origin/taste-pass-production-polish), detached. Nothing committed.

## Milestones

- [x] 1. A applied as-is (42 files). B 3-way merged per file. Only conflict:
  `lib/src/data/exercise.dart` constructor + fields (kept both `isCustom` and
  `animation`/`animationGear`). CLAUDE.md, docs/00, exercise_detail_screen merged clean.
  Custom exercises route to `CustomExerciseScreen`, which has no demo card.
- [x] 1b. B's ADR renumbered 0009 → 0010 (`docs/adr/0010-exercise-demonstrations-are-drawn-not-bundled.md`),
  references fixed in CLAUDE.md, docs/00, figure_rig, exercise_demo, exercise_detail_screen,
  animation_map.py, exercise_demo_test, research note.
- [x] 2. Combined build green before new work: analyze clean, 1340 tests pass
- [x] 3. Decisions recorded: `docs/adr/0011-combined-build-decisions.md`; docs/00, docs/02, CLAUDE.md, turtle-qa SKILL updated
- [x] 4. Schema v9: `custom_exercises.hidden`, `session_exercises.note` + migration test
- [x] 5. Hide from picker (editor action for a logged custom exercise; picker filter; My exercises tag; export flag)
- [x] 6. Swap exercise in place (live session + template editor)
- [x] 7. Notes (set logging, history detail, export, last-note hint)
- [x] 8. Maestro flows `15_swap_exercise.yaml`, `16_exercise_note.yaml` written (run status in Verify log)
- [ ] 9. Verify (validators, sync check, codegen, qa.sh)
- [ ] 10. Install + launch on iPhone 17 D147B7AC, screenshots

Tests for 4–7: `test/swap_notes_hide_data_test.dart`, `test/swap_notes_hide_ui_test.dart`,
migration group `the hide-and-note step (8 -> 9)`.

## Verify log

- analyze clean; validators (exercise, food + its unittest) OK; generators rewrite nothing;
  `tool/sync_generated.sh --check` OK; drift codegen current.
- qa.sh's `generated` and `drift` steps end in a diff against HEAD, which cannot pass on an
  uncommitted tree, so they were run by hand as above.
- Two existing tests adjusted for the note field: `test/set_logging_test.dart` (tap-outside
  point) and `test/qa_load_types_test.dart` (TextField finder excludes the note).
