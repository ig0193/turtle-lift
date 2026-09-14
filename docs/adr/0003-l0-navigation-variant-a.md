# 3. L0 navigation is variant A

Date: 2026-09-14

## Status

Accepted.

## Context

`docs/01` §Navigation and shell specified three tabs — Workout · Muscles ·
Profile — with the tab bar visible everywhere and an open session surfaced by a
Resume card on the Workout landing.

While prototyping the shell, `prototypes/l0-navigation-prototype.html` built
three competing shapes and left the choice open:

- **A — Revised.** Tabs are Workout · Muscles · History; Profile is a header
  avatar; the tab bar shows only at L0; an open session takes over the Workout
  tab instead of showing a Resume card.
- **B — Spec as written.** The `docs/01` shape above.
- **C — A plus in-flow browse.** A, but the mid-session Add-exercise screen can
  also browse by muscle.

`prototypes/l0-tabbar-prototype.html` was then designed against A and says so in
its own header. So the two newest prototypes assumed a navigation shape the
authoritative spec contradicted. Which tabs exist is a product rule rather than
layout, so the repo's own precedence rule (`prototypes/` win on layout, `docs/`
win on rules) did not resolve it.

## Decision

**Variant A.** History is promoted to a tab and Profile moves behind an avatar
in the L0 header.

This is a technical record of the navigation decision. The product rule itself
lives in `docs/01` §Navigation and shell, which this decision amended; the two
records are deliberately separate.

## The invariant this rests on

Variant A's two riders are not loose UI facts. They are the joint precondition
for the app's navigation architecture:

- the tab bar shows **only** at L0, and
- an open session sits **at stack depth zero**, as the Workout tab root.

Together those mean a tab switch is only ever reachable when the navigation
stack is empty, so **no per-tab back stack can ever be observed**. That is what
makes a single root `Navigator` correct: pushed screens cover the shell, the bar
hides for free, and Android system back needs no interception.

**Relaxing either rider reopens that decision.** Showing the bar on pushed
screens, or making an open session a pushed route, would make per-tab history
observable and force nested navigators or a routing package. Anyone revisiting
the bar's reach should treat it as an architecture change, not a UI tweak.

## Consequences

**The cost, which will be re-litigated.** `docs/03`'s browse chain is five
screens deep (muscle → sub-muscle → exercise list → exercise detail → exercise
history). Under A, reaching another tab from the bottom of it takes four back
presses; under B it was one tap. This is the strongest argument against A and it
gets stronger once the Muscles tab has real content.

**Variant C's question stays open.** A does not hide the Muscles tab during a
session — the session overview is an L0 root with the bar visible, so a user can
tab to Muscles mid-session and `docs/03`'s "Add to current workout" stays
reachable that way. Only the pushed Add-exercise screen lacks in-flow browsing.

**Profile's contents need a home.** `docs/00` §11 and `docs/04` assign the
history list, stats, templates and personal details to Profile. History moved to
a tab; the split of everything else between the History tab and the avatar
destination is unresolved and belongs to whoever builds those screens.

**The Resume card is gone, but the rule it sat beside is not.** `docs/02`
Step 2b also says starting a new workout auto-saves an open session. Under A the
session takeover removes both Start-workout entry points from the Workout root,
so that rule currently has no trigger. It was not deleted with the Resume card;
restoring an entry point is part of building the workout flow.
