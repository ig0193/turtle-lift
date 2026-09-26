# 06 — Opal, as a design reference

> **External reference, not a spec.** This describes another product, so that
> "make it like Opal" means something checkable. Nothing here binds the app.
> Where it conflicts with `00`–`04` or `CLAUDE.md`, those win — see
> §What does not transfer, which is the more useful half of this document.

**Sourced**, 2026-09-24, from Opal's own brand kit (`brandkit.opal.so`), its
product site (`opalapp.com`), a screen-by-screen UI breakdown
(`screensdesign.com`) and a motion catalogue (`60fps.design`). Claims below are
from those; anything marked **[inferred]** is a reading, not a quote.

---

## What Opal is

A screen-time app. It blocks distracting apps on a schedule, scores how well
your technology use matches your wellbeing, and rewards you for sticking with
it. Its vocabulary is trademarked and deliberate: **Focus Rules**, **Focus
Timer**, **Opal Score**, **Focus Gems**.

That matters for us because the product's whole problem is the same shape as
ours: **it asks the user to do something unrewarding, repeatedly.** Blocking
your apps is a cost paid now for a benefit felt later. So is logging a set.

---

## 1. The visual system

**Colour.** Pure black `#000000`, white `#FFFFFF`, one grey `#BCBBC0`. Five
gradient accents exist and are reserved for in-app milestone moments —
explicitly *"never as backgrounds or dominant elements."* Gems render only on
pure black, with no text over them.

**Type.** SF Pro Text alone, across every surface, in five weights, each with
its own job:

| Weight | Use | Tracking |
|---|---|---|
| Bold 700 | Headlines | −0.04em |
| Semibold 600 | Subheadings | −0.02em |
| Medium 500 | Body, in secondary grey | — |
| Regular 400 | Supporting and long copy | — |
| Light 300 | Ambient and display, at 70% opacity | — |

The negative tracking on the two heavy weights is the detail most often missed:
large type is set *tighter*, not looser.

**Effects.** Forbidden outright: shadows, glows, effects of any kind on brand
assets; recolouring beyond black or white; stretching or rotating anything.

**The stated principle:** clarity and visual hierarchy over decoration.

---

## 2. Structure

- **One number leads.** The Opal Score collapses sleep, focus and rest into a
  single figure. The marketing does the same — `1h 23m saved daily`,
  `6 years of life reclaimed`.
- **Cards carry features**, one idea each.
- **Guidance arrives in place**, as contextual tooltips on first use, rather
  than being front-loaded.
- **Difficulty is a named choice** — `Normal`, `Timeout`, `Deep Focus` — not a
  slider.
- **An escape hatch is designed in.** `Take a Break` exists mid-session,
  because rigid blocking is not practical. The product plans for the user
  failing its own rule.

---

## 3. Motion

Spring physics throughout, and three patterns worth naming:

- **Tap to reveal** — progressive disclosure rather than everything at once.
- **Press-and-hold to commit** — a progress ring fills while held, on both
  committing *and* leaving. Deliberate actions cost a deliberate gesture.
- **Value transitions** — a streak count animating as it resets, icons with
  sequenced timing, small wiggles for personality.

---

## 4. The idea underneath

**Pay the user back at the point of friction, not somewhere else.**

Blocking apps is the unpleasant moment, so the block screen became the most
characterful surface in the product — customisable, with AI personalities. The
milestone gems reward a habit that otherwise pays nothing back for weeks.
Neither reward is bolted on at the end of a flow; both sit exactly where the
cost is felt. **[inferred, but it is the consistent thread across all four
sources.]**

---

## What transfers to this app

- **Colour as an event, not a surface.** `#D85A30` already has one meaning
  (`00` §12). Opal's discipline is the proof that one accent, used once per
  screen, reads louder than four.
- **One figure leads.** The Log Workout summary bar now does this with
  duration; the same applies wherever three numbers currently sit equal.
- **The weight range.** Five weights with assigned jobs, and negative tracking
  on large type. We use roughly two weights and no tracking.
- **No shadows or glows.** Already true here; worth keeping deliberate.
- **Press-and-hold to commit.** The strongest candidate to borrow. `Discard
  workout` is behind a confirm dialog; a hold-to-confirm is both safer and
  better felt, and `Finish` is the one moment in the app that has earned a
  deliberate gesture.
- **Progressive disclosure.** The ghost chips for notes and rest already work
  this way.
- **Design for the user breaking the rule.** Opal's `Take a Break` has an
  analogue: a workout abandoned mid-set, which this app already handles by
  auto-saving rather than scolding (`00` §9).

## What does not transfer

- **The gem and milestone loop.** `CLAUDE.md` rules out achievements, badges
  and level-ups for V1. This is the single biggest piece of Opal's engagement
  design and it is deliberately out of scope. Do not reintroduce it under
  another name.
- **Pure black and white.** This app has an eleven-colour warm palette, locked
  by `test/theme_palette_test.dart`. Opal's restraint transfers; its swatches
  do not.
- **Gradients.** Not in the palette, not needed, and Opal itself confines them
  to milestone moments we do not have.
- **The onboarding.** Twenty-four steps, a quiz, a generated report and a
  paywall before the core feature. This app has no login, no premium tier and
  no onboarding wizard (`00` §13). The breakdown source calls the length a
  barrier even for Opal.
- **Gamified difficulty tiers.** Naming intensity levels would edge toward the
  prescription `02` refuses to make.
