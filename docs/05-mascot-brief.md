# Mascot — the turtle

## Decision

The app's mascot is **a turtle**. This replaces the zone-lit human figure previously
specced here. That direction is dead and should not be revived.

**Why a turtle rather than a human figure.** Two reasons, one practical, one about meaning.

The practical one: a stylised creature is far more forgiving to draw than a human body.
Everybody knows when a shoulder looks wrong; nobody has an opinion on the correct
proportions of a turtle. Two attempts at a human mascot were rejected. The turtle worked
on the first attempt.

The meaningful one: slow, steady, gets there anyway. That is a three-day-tolerance streak
and "progress over perfection" in one image. A bear would say *strength*, which every
fitness app says. The turtle says what this app actually believes.

## The rule that must not be broken

**The turtle never reacts to inactivity.** It does not get sad, hungry, sick, lonely, or
leave. Nothing decays. It never appears in a notification, and never in copy implying the
user has let it down.

This is not a style preference. The spec rules out shaming, pressure and achievement
mechanics, and a pet is the strongest possible vehicle for all three — the guilt-tripping
mascot is the most famous pattern in this category. Miss this line and the app ships the
exact thing its own spec forbids.

A companion, not a debt collector.

## States

Four, and that is the entire system.

| State | When | Motion |
|---|---|---|
| **Resting** | Default | Slow breathing bob, ~3.5s cycle |
| **Lifting** | A set was just logged | Presses a small bar, ~2s, settles back to resting |
| **Pleased** | Workout finished | Brief cheer with a few sparks, ~1s, then resting |
| **Hidden** | User taps it | Withdraws into the shell; returns on next tap or after a few seconds |

### Orientation — open, decide at build time

The reference art is **standing upright**: the shell is the torso, head sits directly on
top of it, two flipper arms, two feet. That version reads best in a small square corner
tile and keeps one silhouette across all four states.

**But orientation does not have to be uniform.** A horizontal, side-on turtle may suit
some surfaces better — a wide empty state, a bench-press pose, or anywhere the layout is
landscape rather than square. **Pick per surface at build time.** This is a layout call
that is far easier to make against a running screen than in a document.

If both orientations are used, they must still read as the same animal: same shell shape,
same hexagon pattern, same palette, same two-dot face. Do not let them drift into two
different characters.

### Face — deliberately blank

**Two dots. No mouth, no eyebrows, no expressions, ever.**

- At 52px a mouth is three grey pixels; pose and props already carry the state
  unambiguously — arms down, arms up with a bar, arms up with sparks, head gone.
- A neutral face cannot accidentally look strained, smug or disappointed, which quietly
  reinforces the rule that the turtle never reacts to inactivity.
- The head is one ellipse and two circles that only ever translate. No per-state artwork.

**No neck.** The head sits directly on the shell. An earlier draft had a short neck
between them and it read as wrong.

**One generic lifting animation covers every exercise.** The turtle presses a small bar
whether the user is squatting, curling or planking. It reads as "training", not
"demonstrating". Per-exercise animation would be 260 assets and would put this straight
back on the critical path.

**Lifting is triggered by a logged set, never by a timer.** A loop tied to elapsed time
implies the user should be lifting *right now*, which is pressure.

## Where it appears

| Surface | Treatment |
|---|---|
| **Workout overview (session active)** | Small corner tile, ~52px. Primary home. |
| **Celebration** | Hero, "Workout saved" |
| **Empty states** | Resting, above the empty-state copy |
| **Set-logging screen** | Optional, same corner tile — see caution below |
| **App icon / splash** | Static resting pose |

**Not on the share card.** That card's hero is the anatomical muscle map, which carries the
actual information about what was trained. A turtle alongside it competes for the same space
and dilutes both. If a signature is wanted there, a small static turtle beside the wordmark
at the foot — never a second hero element.

**Caution on the logging screen.** Motion next to number entry competes with the field being
edited, while the user is one-handed and tired. If it proves distracting: animate only on set
completion and stay still otherwise, or drop the tile from this screen and keep the turtle on
the overview and celebration. Decide by using it, not by arguing about it.

## Easter egg

Tapping the turtle makes it withdraw into its shell. It returns on the next tap or after a
few seconds.

**Purely cosmetic.** No tap counter, no hidden achievement, no "you found me" toast, nothing
stored, nothing unlocked. The moment it rewards repetition it becomes the badge system the
spec rules out. The hit target is the turtle itself, so it cannot fire while the user reaches
for a set row.

## Technical

- **SVG, flat fills.** No gradients or filters. Palette exactly as the rest of the app:
  shell `#D85A30`, shell pattern `#B34A26`, head and flippers `#F0997B`, feet `#8A5A3C`,
  bar `#8A7D6E`, eye `#17140F`.
- Animate with **transforms only** — translate, scale, rotate. No path morphing.
- **Honour `prefers-reduced-motion`**: all four states render as static poses. This matters
  more than usual on a screen used while physically stressed.
- Must read clearly at **52px** (corner tile) and hold up at **512px** (store icon).
- No gendered or cultural markers. It is a turtle.

## Priority

**Not a blocker, not on the critical path. This is the last thing to build.** The app is
complete and shippable without it. If time runs short it drops with zero impact on
function — which is exactly why it is safe to want.

Several details here are deliberately left open, because they are cheaper to settle against
running screens than in a document: **orientation per surface**, whether the corner tile
appears on the set-logging screen at all, and exact sizing. Decide these during the build,
not before it.
