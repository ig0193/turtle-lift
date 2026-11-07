# ONE DAY theme reference

Colors, gradients, type and component styling from the ONE DAY iOS app
(`nishanth-bs/one-day-fitness-app`, commit `32b2537`), with Flutter equivalents
for reuse in Turtle Lift.

**Source of truth:** `OneDay/Design/Theme.swift` and `OneDay/Design/Components.swift`.
The `DESIGN.md` at that repo's root is an unrelated analysis of Claude's website
(cream/coral). It does not describe ONE DAY, so ignore it.

> **Before adopting anything here:** Turtle Lift has a closed palette.
> `docs/00-build-spec.md` §12 says "No other colours", and
> `test/theme_palette_test.dart` fails on any colour outside it. Any token below
> has to be added to §12 and `AppPalette` first. See "Fitting it into Turtle Lift"
> at the end.

---

## 1. Concept

"Brushed-titanium dark UI with chrome highlights and one iridescent accent."

- **Dark only.** Every screen and sheet forces `.preferredColorScheme(.dark)`.
- **Cool neutrals.** Near-black with a slight blue tint, not warm brown.
- **Chrome** (a silver gradient) fills big numbers and the wordmark.
- **Liquid metal** (silver → ice blue → lilac) is the single accent. It fills the
  primary button, progress rings and bars, and the logo dot.
- **Bevels:** each panel has a 1px gradient hairline border that catches light
  at the top-left corner.
- The system tint (links, toggles, pickers) is `ice`.

## 2. Solid colors

| Token | Hex | Flutter | Role | Uses* |
|---|---|---|---|---|
| `ink` | `#07080A` | `Color(0xFF07080A)` | Deepest background; text on liquid buttons | 16 |
| `ink2` | `#0E1014` | `Color(0xFF0E1014)` | Secondary background | 3 |
| `panel` | `#15171C` | `Color(0xFF15171C)` | Card surface | 4 |
| `panelHi` | `#1D2027` | `Color(0xFF1D2027)` | Raised surface, ghost-button fill | 12 |
| `text` | `#F2F4F7` | `Color(0xFFF2F4F7)` | Primary text | 63 |
| `text2` | `#9EA3AE` | `Color(0xFF9EA3AE)` | Secondary text, eyebrows, field labels | 68 |
| `text3` | `#5C616C` | `Color(0xFF5C616C)` | Muted text, stat labels, units, inactive icons | 100 |
| `good` | `#7CF0C4` | `Color(0xFF7CF0C4)` | Success: done, stocked, suggested increase | 10 |
| `warn` | `#F5C77E` | `Color(0xFFF5C77E)` | Caution; also favourite stars | 13 |
| `bad` | `#FF8A8A` | `Color(0xFFFF8A8A)` | Errors, failures, body-map strain outline | 7 |
| `ice` | `#A9D8FF` | `Color(0xFFA9D8FF)` | App tint; accent icons and glows | 30 |
| `lilac` | `#C9B6FF` | `Color(0xFFC9B6FF)` | Gradient stop; body-map heat end | 1 |

\*How many times each token appears in ONE DAY's Swift code, as a rough measure of
how much it's used. `text3` is the most-used token, so most of the UI is quiet grey.

**Overlays used as colors:**
- Track behind rings and bars: white at 7% (`Color(0x12FFFFFF)`).
- Chrome number glow: white at 8%, blur 8.
- Share-card background: `#050608`. This is the only hex value outside `Theme`.

## 3. Gradients

All diagonal gradients run from top-left to bottom-right.

### Chrome: numbers and wordmark
| Stop | Hex |
|---|---|
| 0.00 | `#FFFFFF` |
| 0.28 | `#C9CDD4` |
| 0.50 | `#7D838E` |
| 0.70 | `#E9ECF0` |
| 1.00 | `#9AA0AA` |

```dart
const chrome = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [Color(0xFFFFFFFF), Color(0xFFC9CDD4), Color(0xFF7D838E), Color(0xFFE9ECF0), Color(0xFF9AA0AA)],
  stops: [0.0, 0.28, 0.5, 0.7, 1.0],
);
```
In Flutter, apply it to text with `ShaderMask(shaderCallback: chrome.createShader, blendMode: BlendMode.srcIn, child: Text(...))`.

### Liquid: the accent
`#E8ECF2` → `#A9D8FF` → `#C9B6FF` → `#F4E3FF`, evenly spaced.

```dart
const liquid = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [Color(0xFFE8ECF2), Color(0xFFA9D8FF), Color(0xFFC9B6FF), Color(0xFFF4E3FF)],
);
```

### Liquid angular: progress rings
The same four colours plus `#E8ECF2` again, so the sweep closes without a seam.
```dart
const liquidSweep = SweepGradient(
  colors: [Color(0xFFE8ECF2), Color(0xFFA9D8FF), Color(0xFFC9B6FF), Color(0xFFF4E3FF), Color(0xFFE8ECF2)],
);
```

### Titanium: panel fill
`#23262D` → `#15171C` → `#1B1E24`, diagonal.

### Bevel: panel and ghost-button border, 1px
White at 28% → 4% → 12%, diagonal (`0x47FFFFFF`, `0x0AFFFFFF`, `0x1FFFFFFF`).
Flutter has no gradient `BorderSide`. Paint the gradient in an outer
`DecoratedBox`, then inset a 1px child with the titanium fill and a radius 1px smaller.

### Background: every screen
`#0C0E12` → `#07080A` → `#0A0B0F`, top to bottom.

## 4. Typography

ONE DAY uses the iOS system font (SF Pro). Display numbers use the SF Rounded
design. There are no bundled fonts.

| Token | Spec | Used for |
|---|---|---|
| `display(size)` | heavy (w800), rounded | Hero numbers (filled with chrome, default 44pt) |
| `title(size)` | semibold (w600) | Section and card titles |
| `body(size)` | regular (w400), default 15 | Body text |
| `mono(size, weight)` | `size + 1`, medium (w500), **tabular figures** | Timers, weights, aligned numbers. It used to be monospaced but was changed to tabular figures to avoid a "terminal" look. |
| `label(size)` | bold (w700), default 11 | Small labels |

Named text styles in components:

| Style | Spec |
|---|---|
| Eyebrow | 13 / semibold / `text2`, sentence case ("On track", not "ON TRACK") |
| Stat value | 22 / bold / rounded / tabular / `text` |
| Stat label | 11 / medium / `text3` |
| Liquid button | 17 / bold / `ink` |
| Ghost button | 15 / semibold / `text` |
| Number-field value | 20 / bold / rounded / `text` |
| Wordmark | 15 / black (w900) / tracking = size × 0.18 / chrome fill |

Flutter equivalent of tabular figures: `fontFeatures: [FontFeature.tabularFigures()]`.
SF Rounded isn't available by name in Flutter. The closest options are the
platform default at w800, or a bundled rounded face. Turtle Lift's typeface
decision is still open (CLAUDE.md, "Still undecided"), so ask before bundling one.

## 5. Shape and spacing

- **Corners are continuous** (squircle) everywhere. Flutter's `RoundedRectangleBorder`
  is circular. Use `ContinuousRectangleBorder` with about 2× the radius to get a similar curve.
- **Radius scale by frequency:** 16 (most common) · 18 · 22 (the default `Panel`) · 9 · 8 · 28 · 14 · 12 · 10.
- **Buttons are capsules** (fully rounded), never rectangles.
- **Panel padding is 16.** Panels stretch to full width with content left-aligned.

## 6. Components

| Component | Recipe |
|---|---|
| **Panel** (card) | Titanium fill, radius 22, 1px bevel border, padding 16 |
| **LiquidButton** (primary) | Capsule, liquid fill, `ink` text, vertical padding 17, full width; 1px white border at 60% with overlay blend; shadow `ice` at 25%, blur 18, y 6; light haptic on tap |
| **GhostButton** (secondary) | Capsule, `panelHi` fill, bevel border, `text` colour, vertical padding 14, full width |
| **MetalRing** (progress) | Track: white at 7%, line width 10. Arc: liquid sweep, round caps, starts at 12 o'clock, glow `ice` at 35%, blur 6 |
| **MetalBar** | Height 6 capsule; track white at 7%; liquid fill; minimum width = height |
| **ChromeText** | `display(44)` + tabular figures + chrome fill + white glow at 8% |
| **Stat** | Value over label, spacing 2, left-aligned |
| **Wordmark** | Liquid dot (0.6 × size) + "ONE DAY" in chrome, spacing 6 |
| **Screen** | Background gradient behind content, ignoring safe areas |
| **NumberField** | Label (`text2`, 15) · spacer · right-aligned value (20 bold rounded, max width 110) · unit (`text3`, 14, width 28) |

**Haptics:** light impact at 0.7 on any button tap, success notification on
completion, selection tick on picker changes.

## 7. Rules the code follows

1. **One accent.** Liquid metal marks the primary action and progress. Nothing else
   competes with it. `ice` is the solid stand-in where a gradient doesn't fit
   (tint, small icons).
2. **Status colours only carry status.** good, warn and bad are used for text and
   icons, never for large fills.
3. **Chrome is for numbers and the brand.** It isn't used on body text.
4. **Use the grey levels for hierarchy.** `text3` appears more than `text`.
5. **Light comes from the top-left.** Every gradient and bevel follows this.

---

## Fitting it into Turtle Lift

Turtle Lift's current palette (`lib/src/theme/app_palette.dart`) is **warm**:
brown-black `#17140F`, cream text, and orange `#D85A30` meaning "active / trained".
ONE DAY is **cool** titanium with an iridescent accent. Mixing the two would look
inconsistent, so pick one direction:

**A. Full re-skin to ONE DAY.** Map the tokens one to one and update §12 and
`theme_palette_test.dart` in the same change:

| AppPalette | → ONE DAY |
|---|---|
| `pageBackground` `#17140F` | `ink` `#07080A` (or the background gradient) |
| `surface` `#211D18` | `panel` `#15171C` (or the titanium gradient) |
| `mutedSurface` `#241F19` | `panelHi` `#1D2027` |
| `border` `#332C22` | bevel gradient, or a flat white at 12% |
| `textPrimary` / `textSecondary` / `textMuted` | `text` / `text2` / `text3` |
| `accentStrong` `#D85A30` | `ice` `#A9D8FF` as the solid colour, liquid for fills |
| `accentLight` `#F0997B` (secondary muscle) | `lilac` `#C9B6FF` |
| `onAccent` `#1B0C05` | `ink` `#07080A` |
| `danger` `#C4553A` | `bad` `#FF8A8A` |

One thing to decide: Turtle Lift gives the accent a single meaning,
"active / this has been worked". ONE DAY uses liquid for both primary actions and
progress. Those two meanings match Turtle Lift's closely, but `good` (mint) would
be a new colour that also reads as "done". It needs its own written meaning in
§12, or it should be left out.

**B. Borrow the treatment, keep the warm palette.** Reuse the structure without the
hues: diagonal surface gradients, bevel hairlines, capsule buttons, chrome-style
numbers, tabular figures and the grey hierarchy, all built from the existing warm
colours. Under the current §12 this still adds new values (gradient stops), so it
still needs a spec change, just a smaller one.
