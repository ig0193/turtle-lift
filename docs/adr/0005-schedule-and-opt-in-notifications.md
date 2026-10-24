# 5. Schedule and opt-in notifications

Date: 2026-10-24

## Status

Accepted. **Amends the "no notifications" rule** in `CLAUDE.md`, `docs/00` §13 and
`docs/01` §Out of scope, for this feature only. Notifications are decided and
will be built **after** the Schedule screen ships.

## Context

Users want to say which days they train, be reminded, and see whether they hit
those days. Four existing rules push against that:

- *No notifications* (V1 out of scope).
- *No multi-day splits or weekly rotation*, and no "today's workout".
- The turtle *never reacts to inactivity* (`docs/05-mascot-brief.md`).
- *Nothing is stored that can be derived* (`docs/01` §Derived values).

## Decision

**1. A weekly pattern, nothing more.** The user picks weekdays. They are never
asked what they plan to do that day, and the app never suggests a workout. This
is a schedule of days, not a split, so the no-split rule holds.

**2. The plan is a dated series, not one value.** A plan entry is the set of
weekdays plus the date it takes effect. A saved plan takes effect from the
**Monday of the current week**, not from the day it is saved: otherwise a user
who picks five days on a Saturday sees "1 of 1", because Monday to Friday
predate the plan. Saving replaces whatever was saved this week; every earlier
week is immutable and keeps the plan it was lived under. This is the shape bodyweight
already uses, for the same reason: one stored pattern, re-read against old
weeks, would turn every past hit into a miss the moment the user changed a day.
Hit / not-hit is **derived on read** — a plan day with a session whose
`performedOn` is that date is a hit — and is never stored.

**3. Notifications are opt-in, local, and fixed-schedule.**
- Permission is requested only when the user turns **Remind me** on, after an
  explain-first sheet. Never at first launch.
- One reminder time applies to all training days.
- Training days and reminders are independent: the days drive the weekly
  summary whether or not notifications are allowed or denied.
- Local notifications only. No server, no account.

**4. A reminder never reacts to behaviour.** No "you missed a day", no
streak-at-risk push, no copy that changes after a gap, no suppressing or adding
reminders based on what was logged. This keeps the notification inside the
mascot rule: it fires because the user scheduled it, not because they were
inactive. The in-app "streak ends tomorrow" hint stays in-app.

**5. Neutral wording.** The summary states counts ("2 of 3 this week · 1 more to
go"). A day with no session is an empty marker, never "missed".

## Consequences

- `CLAUDE.md`, `docs/00` §13, `docs/00` §11 line 150, `docs/01` §Out of scope and
  the streak section's "in-app only" note get an amendment pointing here. The
  mascot brief needs no change: the rule it states is still honoured.
- **Streak is unaffected.** Its 3-day tolerance stays separate from the plan, so
  the app does not carry two competing definitions of consistency.
- **Build order:** dated plan + derived week summary + Schedule screen first;
  notifications last. The **Remind me row ships visible but inert** until then: the
  switch and the explain-first sheet work, nothing is scheduled and no system
  permission is requested. Week starts on **Monday** (confirmed).
- **Plugin constraint:** the notification plugin must ship a `Package.swift`
  (iOS integrates through Swift Package Manager here). Verify before committing
  to one. Android needs the notification permission (13+) and should use inexact
  scheduling to avoid exact-alarm permission, and reminders must survive a
  reboot.
- **Rule exception:** the week summary renders on Profile despite being derived.
  Recorded in ADR 0004; the same figure must not also appear on History.
- Schema: the plan table is a new Drift step numbered **above the current
  version**. Pre-launch, so no migration debt, but the "no later step below the
  current version" rule still applies.
