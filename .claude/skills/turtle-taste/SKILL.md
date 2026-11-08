---
name: turtle-taste
description: Design-taste audit and polish pass for TurtleLift's Flutter screens, adapted from the web `design-taste-frontend` skill (Leonxlnx/taste-skill). Screenshots the real app on a small and a large iPhone, audits each screen against anti-slop rules that fit a native workout logger, then fixes inside the closed palette and the repo's rules. Use when asked to polish, critique, "make it look less generic", or run the taste skill on this app.
---

# turtle-taste

The web taste skill's judgement, re-pointed at a Flutter app. What carries over
is the audit-first habit and the list of tells. What doesn't is everything
about landing pages: heroes, bentos, logo walls, Google Fonts, photo dealing,
shader backgrounds, SEO. Those have no counterpart in a workout logger, so
they are dropped, not translated.

## 0. What outranks this skill

Read these before proposing anything. They win every conflict, and a fix that
breaks one is not a fix.

- `CLAUDE.md`, `docs/00-build-spec.md` (and `01`–`04` over `00`).
- **Closed palette.** `00` §12 lists every colour; `test/theme_palette_test.dart`
  fails on anything else. Never add a hex in a widget. Use `AppPalette`.
  A new colour is a spec change: ask first.
- **One accent, one meaning.** `accentStrong` (shell amber) = trained /
  active / selection / PB. It is not the button colour. `accentLight` (steel)
  = secondary muscle only. `danger` = destructive only. **Primary action =
  chalk fill** (`textPrimary`, `onAccent` label). No gradients anywhere.
- **Typeface is undecided.** Do not bundle or fetch a font. The web skill's
  font-pairing advice does not apply until the user picks one.
- **Pinned header** via `AppScreen`. No collapsing or floating app bars.
- **Prototype wins on layout** (`prototypes/screens.html`), docs win on rules.
- **No out-of-scope features** (`CLAUDE.md` "Out of scope"). Polish only.
- **Exercise content is reviewed copy.** Never edit `setup` / `posture` /
  `execution` / `commonMistakes`.
- **No commits** unless the user asks.

## 1. Capture (the stand-in for headless Chrome)

```sh
tool/taste_shots.sh                    # iPhone 17e + iPhone 17 Pro Max
tool/taste_shots.sh "iPhone 17"        # or name devices
```

This runs `integration_test/taste_shots_test.dart` through `flutter drive`
and writes `build/taste_shots/<device>/NN-<screen>.png`: every screen the app
reaches (~38: tab roots, templates, picker, all four logging variants,
exercise detail and history, summary, delete confirmation, Muscles lists and
search, History detail, Profile, data screens, Schedule). Each section is
independent, so one broken step is logged as `skipped` and the rest still
shoot. Read every PNG. Audit what is on screen, not what the widget code
implies. To cover a screen it misses, add a section to that test.

**Also shoot at the largest text size.** Set it, shoot, set it back:

```sh
U=<17e udid>; xcrun simctl ui $U content_size accessibility-extra-extra-extra-large
TASTE_SHOTS_DIR=build/taste_shots/iPhone-17e-largetext flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/taste_shots_test.dart -d $U
xcrun simctl ui $U content_size large
```

The app clamps system text at 1.3x (`main.dart`); anything clipped or
overflowing at that size is a FAIL.

## 2. Design read (one line, before any change)

> Native dark workout logger, used mid-set with one thumb, glanced at between
> lifts. Calm, dense-but-legible, graphite and chalk with one shell-amber
> accent that only means "worked".

Dials for this app (from the web skill's three dials):
`DESIGN_VARIANCE 3` (predictable beats clever on a gym floor) ·
`MOTION_INTENSITY 3` (short, purposeful, reduced-motion honoured) ·
`VISUAL_DENSITY 6` (sets and numbers are the content).

## 3. Audit (write it before touching code)

Per screen, list what is doing work, what is filler, and which rule below it
breaks, with the screenshot name. Then rank by how often a user sees the
screen: set logging and the Workout landing first.

## 4. Rules that carry over

Severity, from tasteskill.dev: **FAIL** = not done, fix it. **WARN** = may stay
only with a reason you can state to a designer, written in the report.

**Per screen (tasteskill.dev app-screen rules)**
- Each screen answers one question first, and its largest block carries the
  answer (set logging: "what do I lift now?" = the set rows).
- Every state is built: empty, zero, first-time, error. No "Not built yet",
  no dev notes, no "sample data" copy in anything a user can reach. FAIL.
- Totals are computed from the rows, never typed.
- No invented data in shipped UI; sample data is debug-only.

**Colour**
- One accent on screen at a time. If amber appears on more than trained
  muscles, the active tab, the selection and the PB mark, it has lost its
  meaning. Steel on anything but a secondary muscle is a FAIL.
- No glows, no gradients, no gradient text.
- No pure `#000000` surfaces (scrims and shadows are overlays, fine).
- Status never by colour alone: pair with an icon or a word.
- Contrast: muted text 4.5:1 or better on every surface (`textMuted`
  `#8B8B90` was chosen for this); primary text 7:1. FAIL below.
- Exactly one filled (chalk) button per view: the main action. Secondary
  actions are text (`GhostButton`), not stacked capsules. Selection controls
  are outlined (raised neutral + amber border/label), never filled.
- One PB mark: the word "PB" in amber (`kPbMarkStyle`). No pill, no trophy,
  no star.

**Typography** (platform font until decided)
- Hierarchy by weight and grey level (`textPrimary` / `textSecondary` /
  `textMuted`), not by ever-larger sizes. `textMuted` should be the most-used
  grey.
- One size scale: 12 / 13 / 15 / 17 / 20 / 24 (`AppTypeScale`), plus the
  fitted set-logging numeral. No half points. Weights 400 / 500 / 600, no
  700. Zero letter spacing below 16pt.
- Numbers that change or align (weights, reps, times, counts) use
  `FontFeature.tabularFigures()`, so digits don't jitter as they change.
- **Sentence case everywhere.** Labels 13pt semibold `textSecondary`
  (`kLandingSectionLabelStyle`), never tracked capitals, never
  `toUpperCase()`. Chips too ("Barbell", not "BARBELL"). The only caps in the
  app is the summary card's wordmark.
- **Nothing under 12pt** (iOS caption range; the web skill's 13px floor is for
  page text). The tab bar labels are the platform exception.
- No em-dash or en-dash as a separator in UI strings. Use a period, comma,
  colon or line break. Ranges use a hyphen.

**Shape**
- One radius scale: 16 for cards and fields, capsule for buttons and chips.
  A stray 10 or 12 next to a 16 reads as a bug. Status tags, counts, equipment
  and set lists are quiet text, not pills.
- Cards only where elevation means hierarchy. Otherwise group with dividers
  or space.

**Layout**
- Thumb reach: primary actions sit in the bottom third. Tap targets ≥ 48pt.
- Nothing important hides under the floating tab bar or the pinned Start
  bar. The last item in a scroll view must scroll clear of both.
- Check the small phone (17e) for wraps, clipped labels and overflow, and the
  large phone (Pro Max) for stretched, empty-feeling layouts.
- No repeated identical rows where the data differs in kind. Vary by content,
  not decoration.

**States**
- Every list has an empty state that says how to fill it (`EmptyState`).
- Disabled looks disabled (`mutedSurface` fill, `textMuted` label) and says
  why nearby.
- Pressed feedback on custom tappables (`GestureDetector`-built buttons have
  none by default).
- Button labels fit on one line at 17e width.
- A number never clips: values shrink to fit their box (`StepperField`), and
  never break from their unit.
- Contrast: text on a chalk or amber fill uses `onAccent`; muted text still
  passes WCAG AA for its size against its surface.

**Motion**
- Purposeful only (state change, spatial continuity). 150–300ms.
- Respect `reduceMotion` / `disableAnimations` the way `GlassTabBar` does.
- No looping or idle animation. The mascot never reacts to inactivity.

**Content tells**
- No filler verbs ("Elevate", "Unleash", "Seamless"), no fake-perfect
  numbers in sample data, no generic names.
- No decorative status dots, no version stamps, no "Step 1 / Step 2" labels.

## 5. Fix

- Smallest change that clears the rule. Theme-level first (`app_theme.dart`,
  `app_palette.dart`, `app_typography.dart`), then shared widgets
  (`ghost_button.dart`, `empty_state.dart`, `disclosure_row.dart`), then a
  single screen.
- A finding that needs a new colour, a font, or a layout that departs from
  the prototype is a question for the user, not a fix.

## 6. Gate (all must pass)

```sh
flutter analyze
flutter test
tool/taste_shots.sh        # re-shoot, and look at the before/after pairs
```

Report what changed per screen, what was found but left for the user, and
which tests had to change and why.
