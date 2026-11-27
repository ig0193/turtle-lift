# 16. The Profile tab becomes You, History moves into it, and Diet gets a tab

Date: 2026-11-15

## Status

Accepted. The user asked for this directly.

**Supersedes the "History as a tab" half of
[ADR 0003](0003-l0-navigation-variant-a.md)** and **amends
[ADR 0004](0004-profile-returns-as-a-tab.md)** (the fourth tab is now You, not
Profile), **[ADR 0007](0007-diet-in-profile.md)** (Diet is a tab, not a Profile
segment) and **[ADR 0015](0015-diet-is-a-log.md)** (Profile's segments are no
longer Personal | Diet). Still four tabs: Diet takes the slot History left.

## Context

History and Profile were two tabs about the same person: what they did, and what
they told the app. Diet sat inside Profile as a segment, which hid the screen a
user opens most days (what did I eat) behind the one they open least (settings).
The bar had a tab for reading the past and none for logging a meal.

## Decision

1. **The tab bar is Diet | Workout | Muscles | You.** Four tabs stays the
   ceiling (ADR 0004). **The app still opens on Workout**, now the second tab:
   it is the tab people come to use, and "first in the bar" is not "default".
   The default is `kWorkoutTabIndex`, found by what the tab is, never by number.
2. **Profile is renamed You, and becomes three segments: Profile | Activity |
   Analysis.**
   - **Profile** is the old Personal pane, unchanged (details, bodyweight,
     templates, reminders-in-settings, export, delete, About).
   - **Activity** is the old History tab, unchanged: the stats line, the
     calendar, Recent, "See all". Same widgets, same providers.
   - **Analysis** is an empty pane for now, with one line, "Analysis is coming
     soon." It is a placeholder, not a feature: nothing stores or computes for it.
3. **Diet is its own L0 tab** (`DietRoot`, header "Diet"). `DietPane` is
   unchanged; it just no longer shares a scroll view with Personal. A diet
   reminder tap and a reminder launch open the Diet tab, with no segment to
   select.
4. **The segments live in an `IndexedStack`**, each with its own scroll view,
   so Activity keeps its scroll position and calendar month while the user
   looks at Profile. The old rule that a switch jumps to the top (KTD3) existed
   because three panes shared one scroll view; with one each there is nothing to
   reset. The selected segment is still in memory only and opens on **Activity**: what
   the user did is what they come to You to read, and Profile is a settings
   pane they visit rarely.
5. **The placement rule is unchanged, one level down.** Anything computed from
   session rows lives on **Activity**; anything the user typed lives on
   **Profile**; **no figure appears in both**. They now share a tab, and still
   not a pane.
6. **Names.** The word "History" leaves the user's vocabulary (the bar, the
   header, copy: "It stays in Activity", "Add your bodyweight in You, Profile").
   **It stays in code**: `HistoryRoot`, `history_*.dart`, `historySessionsProvider`
   and the ADRs that say "the History tab" all mean Activity. Renaming them
   buys nothing and loses `git blame`.
7. **Tab glyphs.** Diet is a bowl with two wisps of steam; You keeps the head
   and shoulders; the clock that was History's is removed with it.

## Consequences

- **Tab indexes moved**: Diet 0, Workout 1, Muscles 2, You 3. Anything that
  named a tab by number was wrong by construction; code and tests now read the
  index off the shell (`kDietTabIndex`, `kWorkoutTabIndex`, `kYouTabIndex`).
  The shell's "only Workout's header varies" check is by tab type, not by
  position.
- **The Activity pane sits one segment deep.** Finishing a workout still lands
  on the Workout tab; "Start a workout" in an empty Activity pane still goes
  there. A past workout is one more tap away than when History was a tab, which
  is the price of giving Diet the slot.
- **Maestro flows and integration tests** that opened History or Diet by tab or
  segment were rewritten and not run here (iOS simulators).
- **Prototypes** still draw the old five-surface layout; the visual reference
  stands for everything else.
