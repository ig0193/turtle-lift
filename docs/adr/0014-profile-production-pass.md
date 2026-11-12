# 14. Profile: honest inputs, honest reminders, complete export

Date: 2026-11-10

## Status

Accepted. The user asked the agent to "take the best decision for the app and
build", so the recommendations in `docs/research/profile-tab-audit.md` are the
decisions. **Amends `docs/00` §11 and `docs/04`** (bodyweight range, the Personal
pane's rows and About block, the pinned segment control, export contents).
Builds on ADR 0004 (authored lives on Profile), 0005 (reminder rules), 0007
(Diet, the protein rule) and 0013 (one date format).

## Context

The audit found Profile honest about placement, but lax about inputs and
reminder state. A 0.5 kg bodyweight was accepted and, being immutable after
its day, could never be removed. Remind me could be on with nothing to fire.
The Diet Reminders row said "On" or "3 a day" when nothing would arrive.
Export left out entered data. The segment control scrolled away on a long
Diet day. Bugs B1-B13 are in the audit.

## Decision

1. **Bodyweight is 20 to 250 kg** (`kMinBodyweightKg`, `kMaxBodyweightKg`,
   `parseBodyweight`). Anything else shows "Between 20 and 250 kg" under the
   field and records nothing. 250 kg is chosen with the protein rule: 1.6 g/kg
   at 250 kg is the 400 g target cap, so a valid weight always gives a
   suggestion that can be stored. After Record, a live-region line says what
   was recorded. The screen says that today's entry can be replaced until
   midnight, and stays after that (the KD5 immutability rule is unchanged).
   Log rows use `date_labels.dart`.
2. **The weigh-ins have a trend line** on Personal details, from two entries:
   a `CustomPainter` in greys only (a weight change is neither a record nor
   "worked", so no amber), and one spoken sentence ("From 72 to 74.5 kg over 3
   weigh-ins since 27 Oct."). It is authored data, so ADR 0004's placement
   rule is not touched.
3. **A weigh-in that moves the protein suggestion says so, once, at that
   moment.** If a target is stored and the new 1.6 g/kg suggestion differs,
   the status line adds "Protein suggestion is now N g." with **Update
   target**. That opens the target screen with N filled in, and nothing is
   stored until Save. The stored target never changes by itself (ADR 0007).
   The target screen names the weigh-in its suggestion uses ("your weigh-in
   on 10 Nov").
4. **The segment control is pinned** above the pane's scroll view, for the
   same reason the header is pinned: the way to the other panes is never
   scrolled away.
5. **Reminders never say "on" when nothing will fire.**
   - Remind me with no training days says "Pick at least one training day
     above to get a reminder."
   - The Diet Reminders row reads "None chosen" with the master on and nothing
     picked, and "Off in Settings" when the OS refuses notifications. Slot
     headers then drop their time.
   - `notificationPermissionProvider` holds the OS answer, re-read on resume,
     and is never stored.
   - The notifications-off note has **Open Settings**: method channel
     `dev.indresh.turtleLift/system` (`openSettings`), handled in
     `AppDelegate.swift` (the app's Settings page) and `MainActivity.kt` (its
     notification settings). No plugin is added.
   - Time rows are named ("Reminder time", "Breakfast time"), and the disabled
     reason is said once.
   - Saving training days or reminder preferences shows the new value before
     the database write, with rollback on failure, so two quick taps never
     lose one.
6. **Export is complete and spreadsheet-ready.**
   - It is enabled by any entered data, a schedule or a reminder setting
     included, and the counts list the training days.
   - The JSON gains `reminders` (switches and HH:MM times). It is an additive
     key, so `formatVersion` stays 1.
   - The share sheet carries a second file, `turtlelift-sets-YYYY-MM-DD.csv`:
     one row per completed set, with units in the column names (`weight_kg`,
     `duration_sec`). Entered data only: the title and template as stored,
     never the resolved title.
   - Delete all data has **Export first** on its screen, and says that files
     already exported or shared are not touched.
7. **The Personal pane shows its values and ends with About.** The Personal
   details row reads "74.5 kg · female diagram" (authored values). About
   carries the version (`lib/src/app_info.dart`, which a test checks against
   `pubspec.yaml`), the privacy promise ("Your data stays on this phone…") and
   **Open-source licences** (Flutter's `LicensePage`).

## Not decided here (left for the user)

- **Pounds.** kg-only stays (`docs/04`, `00` §11). The audience the food list
  serves uses kg, and lb touches every input, stepper, format, chart, PB
  comparison and the export. It needs its own ADR, with plate-rounding rules.
- **Import from an export file.** It needs a file-picker plugin with Swift
  Package Manager support, and merge rules against the immutable weight series
  and dated plans. iOS device backups already carry the database.

## Rejected

Editing or deleting past weigh-ins (it re-prices logged calories; KD5).
Automatic protein targets that follow weight (they rewrite an authored
number). Body measurements and photos (beyond `docs/04`'s two personal
fields). Health sync (integrations are out of scope). A typed "DELETE"
confirmation (two deliberate steps already, and Export first is the softer
exit).

## Consequences

- **No schema change.** Everything is validation, UI, derived-on-read or the
  export format.
- `test/profile_screen_test.dart`'s "nothing derived" sweeps were widened on
  purpose: the version string is allowed, and the bodyweight and gender
  providers are authored.
- New native code: a small method handler in `AppDelegate.swift` and
  `MainActivity.kt`.
