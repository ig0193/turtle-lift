# Open points after the taste pass

Written 2026-11-08, after the turtle-taste production pass. None of this work is
committed yet.

## Before shipping

### 1. ~~The "Remind me" switch does nothing~~ Resolved
- **Resolved by U16** of `docs/plans/2026-11-08-1702-feat-diet-weekly-protein-plan.md`.
  The switch and time are stored (`ReminderPrefs`, schema v7). Turning it on
  shows the explain-first sheet, then the system prompt. Once allowed, one
  weekly notification is scheduled per training day at the chosen time
  (`lib/src/data/training_reminders.dart`). They are rescheduled after every
  plan or time change, at boot and on resume. If permission is refused, the
  switch stays off with a line pointing to Settings. The row is hidden where
  notifications are unsupported. The shared controls are in
  `lib/src/ui/reminder_controls.dart`.
- **Still to check on a device:** a delivered training reminder, and that
  tapping it opens Profile → Schedule (the simulator smoke in the plan's
  Verification Contract).

### 2. Export hasn't been tried end to end
- **Where:** Profile → Export everything (`lib/src/ui/data_screens.dart`).
- **Tested so far:** the file contents, the dated file name and the disabled
  empty state, all in unit and widget tests.
- **Not tested:** tapping Export through to the iOS share sheet on a simulator
  or phone, then saving to Files and opening the JSON.
- **To check:** the success and "cancelled" status lines appear afterwards.

### 3. Try Delete all data once on a device
- Tests cover the wipe and the restart.
- **To check:** after confirming, the app comes back on a clean, empty state
  with no stale data on any tab.
- In debug builds the sample data is not re-seeded after a wipe. That's
  intended.

## Decisions for you

### 4. Palette replaced (resolved)
- The titanium palette and its ice-to-lilac gradient were replaced by Chalk &
  Shell (`docs/research/unslop-audit.md`): graphite neutrals, a chalk primary
  button, shell amber for worked / active / PB, steel for the secondary muscle,
  no gradients. Recorded in `00` §12, `01`, `CLAUDE.md` and the turtle-taste
  skill.

### 5. Muted grey contrast (resolved)
- `textMuted` is `#8B8B90`: 4.68:1 on the muted surface, 5.2:1 or better on the
  others, above WCAG AA's 4.5:1.

### 6. Sentence case departs from the prototype
- `prototypes/screens.html` uses tracked capitals for labels and chips.
- The app now uses sentence case everywhere, except the TURTLELIFT wordmark on
  the summary card.
- **Decide:** update the prototype to match, or record the difference in the
  docs.

### 7. The typeface is still undecided
- The app uses the platform font.
- If you choose Inter, it has to be bundled as an asset: the app is offline
  and can't fetch a font at runtime.

## Minor, kept on purpose (WARN)

### 8. Summary card at the largest text size
- At the 1.3× clamp, the stat labels wrap to three or four lines.
- They're readable but cramped.
- **Options:** shorten the labels, or stack the stats vertically when text is
  scaled.

### 9. "·" separators in data lines
- Set and session lines use middle dots, for example "Logged · 2 personal
  bests". The web rules ration them.
- They're a normal data separator on iOS, so they stay.

### 10. 12pt text floor instead of 13px
- tasteskill.dev's 13px floor is meant for web page text.
- 12pt is the iOS caption size, and the reason is stated in the skill file.

### 11. Two screenshot-walk shots miss their empty state
- **Shots:** the empty muscle search and the empty exercise picker
  (`integration_test/taste_shots_test.dart`).
- **Problem:** neither shot shows the empty state. That's a gap in the walk,
  not an app bug; widget tests cover both states.
- **Fix:** make those walk steps type a query that matches nothing.

## Housekeeping

- **New dependencies:** `share_plus` and `path_provider`. Both ship a
  `Package.swift`, so the Swift Package Manager rule holds. `flutter_driver` is
  a new dev dependency.
- **Change size:** 51 modified files and 10 new ones, none committed. Ask when
  you want a commit.
- **Re-check after UI changes:** run `tool/taste_shots.sh`, then the
  large-text run described in `.claude/skills/turtle-taste/SKILL.md`.
