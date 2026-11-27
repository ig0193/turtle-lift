# 17. Diet gets a date picker and a sliding week strip

Date: 2026-11-15

## Status

Accepted. The user asked for both directly. **Amends
[ADR 0015](0015-diet-is-a-log.md)** (which days of the log can be reached and
edited) and builds on [ADR 0016](0016-you-tab-and-diet-tab.md) (Diet is a tab,
so it has a header to put a control in).

## Context

The Diet tab showed one fixed Monday-to-Sunday week and nothing else. A meal
forgotten on the 3rd could be logged on the 4th only if the 3rd was still in the
current week; an older day could not be reached at all, and there was no way to
see which days had been logged. Activity already answers both with a calendar.

## Decision

1. **A calendar button in the Diet header** ("Pick a date"). It opens a sheet
   with a month calendar in Activity's look: swipeable months, a dot under every
   day that has food logged, a ring on today, a filled disc on the selected day.
   A "Today" button returns to today. It opens on the month of the selected day.
2. **Picking a day selects it, closes the sheet and brings that day's
   Monday-to-Sunday week into the strip.** One function, `showDietDay`, does
   both; the picker and a diet reminder tap use it, so a reminder tap puts
   today's week back.
3. **Today and earlier only**, as the log already is (ADR 0015): a future day's
   cell is inert and dimmed, and there is no month after the current one. **Any
   past day can be picked and edited**, not only days of the current week: the
   store has only ever refused the future. ADR 0015's "past days of the current
   week" described the strip, not the store.
4. **The week strip is a window of exactly seven days that slides one day at a
   time.** Dragging left shows later days and dragging right earlier ones, one
   day per cell-width of travel, so it follows the finger. A quick fling that did
   not travel a cell still moves one day. The window opens on this week's Monday
   and a picked date resets it to that date's Monday.
5. **The window never slides past this week's Monday**, and not back further
   than 3650 days (the calendar's ten years). Days after today can appear in it
   (inert) but there is nothing to find by sliding on into the future.
6. **No caption names the dates.** An earlier draft added a "26 Oct to 1 Nov" line
   once the strip left this week; it was removed as unwanted. The dates in the
   cells and the picker's month label are what place the user.
7. **The strip's cells are named by position, not weekday**, because the first
   cell is any weekday once it slides. Each cell's label still says its weekday,
   derived from its date. Screen readers cannot drag, so the strip offers "Show
   earlier day" and "Show later day" as custom actions.
8. **The markers are derived** (`dietLoggedDatesProvider`) from the log, never
   stored: adding, editing or removing a food moves a dot with no refresh.
9. The selected day, the strip's start and the picker's month are in memory
   only. A resume on a new date snaps the strip back to this week, as the
   selected day already did.

## Consequences

- **`dietWeekProvider` is replaced by `dietStripProvider(start)`**, keyed by the
  strip's first day, because "this week" is no longer the only run of seven days
  worth computing.
- **A forgotten meal can be logged any time later**, which also means old days can
  be changed silently. That is the same trade every other editable record in the
  app makes (Activity lets a past workout be edited and deleted).
- **The calendar duplicates Activity's grid cell and page code** rather than
  sharing it: Activity's is tied to sessions, month totals and streak runs, and
  extracting a common widget would put Activity's tests at risk for no new
  behaviour. If a third calendar appears, extract then.
