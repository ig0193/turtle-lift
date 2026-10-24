# 4. Profile returns as the fourth tab

Date: 2026-10-24

## Status

Accepted. **Supersedes the Profile half of
[ADR 0003](0003-l0-navigation-variant-a.md)** (Profile behind a header avatar).
The rest of 0003 — History as a tab, the bar showing only at L0, an open session
sitting at stack depth zero — stands unchanged.

## Context

ADR 0003 moved Profile behind an avatar to make room for History as a tab. It
recorded its own cost: the app's only template-authoring surface sat behind a
small disc, "poor discovery for something a new user may want in week one", and
it patched that with a labelled avatar and a Workout-tab route.

Profile is about to gain a Schedule: training days, reminders, and a weekly
summary of how the plan is going. That is something the user returns to
weekly, not a settings page opened once. It also puts three jobs on one screen
(personal details, custom workouts, schedule), which is more than an avatar
destination should carry.

## Decision

**Four tabs: Workout · Muscles · History · Profile.** The header avatar is
removed. Profile is a tab root, so it is an `AppScreen.root` with the bar
visible.

Inside Profile, a segmented control splits it in two:

- **Personal** — personal details, My workout templates, data actions.
- **Schedule** — week summary, training days, reminders. See ADR 0005.

## Why this does not reopen 0003's invariant

0003 rests on two riders: the bar shows only at L0, and an open session is the
Workout tab root. A fourth tab changes neither. A tab switch is still only
reachable with an empty stack, so no per-tab back stack is ever observable and
the single root `Navigator` stays correct. This is a change to the bar's
contents, not its reach.

## Consequences

- **The discovery workaround is no longer needed.** The labelled avatar goes
  with the avatar. The Workout tab's route to template management can stay as
  convenience, but is no longer load-bearing.
- **The placement rule changes its wording, not its logic.** "Derived lives on
  the tab; authored lives behind the avatar" becomes "derived lives on History;
  authored lives on Profile". The test is the same one-sentence test, and
  `app_database.dart`'s preference-vs-derived axis still agrees with it.
- **One named exception to that rule.** The Schedule pane's week summary is
  computed from sessions yet lives on Profile. It is the feedback loop for the
  plan the user has just typed, not a stat. Condition: the same figure must
  never also render on History. If a History calendar is added later, it must
  either own the summary or leave it here. (As built, the History calendar is a
  plain month view of trained days with no plan overlay or weekly count, so there
  is no overlap today.)
- **Four tabs is the ceiling for a bar this size.** A fifth needs a new ADR.
- **Cost still carried from 0003:** the five-screen Muscles browse chain. A
  fourth tab does not make it worse.
- Existing avatar code (`ProfileAvatarButton`, its geometry tests, the Workout
  header's trailing slot) is removed or repurposed in the build ticket, not
  left dead.
