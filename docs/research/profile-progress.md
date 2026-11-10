# Profile tab build: progress

Worktree detached at `origin/taste-pass-production-polish` (a7b6fa1). Plan:
`docs/research/profile-tab-audit.md` (eight slices). The user asked the agent to
decide ("take the best decision for the app and build"), so the recommendations
there are the decisions; ADR 0014 records them.

Baseline: `flutter test` 1523 green.

## Slices

| # | Slice | Status |
|---|---|---|
| 1 | Bodyweight entry (B1 range, B2 dates, B3 status + today copy) | done; `test/profile_bodyweight_test.dart` (9) |
| 2 | Bodyweight trend + suggestion follow-up (B13) | done; `test/profile_trend_test.dart` (7) |
| 3 | Profile root: pinned segment, row values, About (B4, B12) | done; `test/profile_personal_polish_test.dart` (5) |
| 4 | Reminders (B5-B8, B11) | done; `test/profile_reminders_test.dart` (12) |
| 5 | Data (B9, B10, CSV, Export on delete screen) | done; `test/profile_data_test.dart` (7). Full suite 1562 green |
| 6 | Docs (ADR 0014, 00, 04, CLAUDE.md, turtle-qa) | done |
| 7 | Maestro flows 28+ and updates | done: 28, 29, 30 new; 04 (confirmation line, row value) and 05 ("Reminder time") updated |
| 8 | Verify + install + screenshots | done: `tool/qa.sh --fast` all PASS (1562 tests). Maestro 17e: 30 of 30 YAML flows pass, 11 scripted pass; 07's three sub-cases each passed in at least one of four runs, failing only when the simulator push banner never appeared (screenshots show the home screen with no banner): infrastructure, not app. Pro Max and 17e largest-text spot checks clean (text size reset to `large`). Seeded debug build installed over the review iPhone 17's data, running. Screenshots in the session scratchpad `profile-build/` |

Fixes found on device: plain texts merged into one accessibility node ("Version …\nYour data stays …", the no-days note with the days note), so new notes are `Semantics(container: true)`; the trend chart's lowest label overlapped the first dot, so labels got a left gutter; the target field gained a Maestro identifier.

## Log

- Slice 1: `parseBodyweight`, `kMinBodyweightKg` 20 / `kMaxBodyweightKg` 250 in `personal_details_store.dart` (assert in `record`). Personal details: reason under the field, Record dims when invalid (a tap still validates, so a stale frame cannot record junk), live-region status line, correction note, `shortDateLabel` rows. Regression test: a gender write keeps the protein target.
- Slice 2: `lib/src/ui/bodyweight_trend_chart.dart` (`bodyweightTrendSummary`, greys-only `BodyweightTrendPainter`), shown from two weigh-ins. After Record, if a target is set and `suggestedTargetFor(kg)` differs: "Protein suggestion is now N g." + Update target, which opens `ProteinTargetScreen(initialGrams:)`; nothing is stored until Save. Target screen working line names the weigh-in date (deliberate copy change; old test updated).
- Slice 3: `ProfileRoot` is a Column: pinned segment control, then the ListView. `personalDetailsSubtitle` ("74.5 kg · female diagram"). About: `lib/src/app_info.dart` (`kAppVersion`, checked against pubspec), privacy note, Open-source licences row → `LicensePage`. `profile_screen_test` sweeps widened on purpose (version digits; bodyweight and gender providers are authored).
- Slice 4: training plan and reminder prefs saves are optimistic with rollback. `lib/src/data/notification_permission.dart` (`notificationPermissionProvider`, refreshed on resume; screens push what they read; `openAppSettingsProvider` over channel `dev.indresh.turtleLift/system`, handled in `AppDelegate.swift` and `MainActivity.kt`). Schedule no-days note; time rows named ("Reminder time", "Breakfast time"); disabled reason once; Diet row "None chosen" / "Off in Settings", slot time hidden when the OS refuses. Two old diet reminder tests updated for the deliberate change.
- Slice 5: `buildSetsCsv` + `setsCsvFileName`; `buildExportJson(reminders:)`; Export shares JSON + CSV; counts gain Training days; export enabled by a schedule or reminder setting alone; Delete screen: Export first link, "Files you already exported or shared are not touched."
