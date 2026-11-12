# Theme originality: legal risk and an original palette

Research note, 2026-11-08. **This is not legal advice.** It summarises public
law and store policy so you can decide whether to talk to a lawyer. It is not a
substitute for one.

## Short answer

- **Legal risk from the colours alone is low.** US copyright does not protect
  "mere variations of … coloring". A colour or colour scheme is protected only
  as a trademark or trade dress, and only once the public links it to one
  source. A private app's palette has not had that chance to become known.
- **The real exposure is how the theme was made, not the hex values.**
  `docs/one-day-theme-reference.md` was written by reading another developer's
  source code (`nishanth-bs/one-day-fitness-app`, which `gh` reports as a
  **private** repo with **no licence**). It copies that app's token names
  ("liquid", "chrome", "ink", "panel"), component recipes, gradient stops and
  even per-token usage counts. Hex values are facts. A documented re-skin
  "taken from" a named app is the kind of evidence of copying that matters under
  EU unregistered-design law and Apple guideline 4.1(a). If you have the
  author's permission, most of this goes away. Get it in writing.
- **What reads as copied:** the ice-to-lilac "liquid" gradient on capsule
  buttons, the exact 11-hex set, and the ONE DAY names in code comments and
  docs. **What is generic:** near-black dark mode, a grey text ramp, capsule
  buttons, 16pt radii, sentence-case labels.
- **Recommendation: "Lagoon".** Blue-black-green neutrals, a solid sea-teal
  accent `#4FD1C5`, a sand secondary-muscle colour `#CDB386`, a coral danger
  colour `#FF8F80`, and **no gradient**. It keeps the calm, cool mood and passes
  every contrast target. It also separates primary from secondary muscles much
  better for colour-blind users than ice/lilac does (see the numbers below).

---

## 1. Legal findings

### Copyright: colour is not protected, but artwork can be

- US Copyright Office regulations list, as material not subject to copyright,
  "mere variations of typographic ornamentation, lettering or coloring"
  (37 CFR 202.1(a)) [1].
- A palette is a list of colour values, so it falls on the unprotected side.
  Screen layouts and original graphics (illustrations, icons, a mascot) can be
  protected as works. TurtleLift's layouts come from its own prototypes, not
  ONE DAY, so this is not the issue here.
- Source code is protected. Reading it to extract values is not the same as
  copying it into the app, but the reference doc does reproduce small Dart
  translations of ONE DAY's gradients. That copied code is now in `app_palette.dart`.

### US trade dress (Lanham Act §43(a))

- §43(a) lets an owner sue over a "false designation of origin" that "is likely
  to cause confusion … as to the affiliation" of goods (15 U.S.C. §1125(a)(1)(A))
  [2].
- For **unregistered** trade dress, "the person who asserts trade dress
  protection has the burden of proving that the matter sought to be protected is
  not functional" (§1125(a)(3)) [2].
- Product design, like colour, is **never inherently distinctive**: it is
  protectable "only upon a showing of secondary meaning" (*Wal-Mart v. Samara
  Bros.*, 529 U.S. 205 (2000)) [3]. A private or little-known app's look has not
  acquired secondary meaning.
- *Apple v. Samsung*, 786 F.3d 983 (Fed. Cir. 2015): the court reversed the
  jury's iPhone trade-dress verdicts. It held that the unregistered elements
  "serve the functional purpose of improving usability", and that the
  undisputed facts showed "the functionality of the '983 trade dress" (the icon
  grid) [4]. Even Apple, with huge recognition, could not protect a UI look built
  from usability choices. Dark backgrounds, readable grey ramps and pill buttons
  are just as functional.

### Single-colour trademarks

- *Qualitex v. Jacobson*, 514 U.S. 159 (1995): there is "no rule absolutely
  barring the use of color alone" as a trademark, but only with secondary
  meaning, and subject to functionality. The test for aesthetic functionality is
  "whether the recognition of trademark rights would significantly hinder
  competition" [5].
- *Christian Louboutin v. Yves Saint Laurent*, 696 F.3d 206 (2d Cir. 2012): the
  red sole is a valid mark, but limited "to uses in which the red outsole
  contrasts with the color of the remainder of the shoe". The court also rejected
  a rule that a single colour can never be a mark in fashion [6].
- Takeaway: colour marks exist, but they are narrow, need proof of public
  recognition, and cover a specific use. None of that fits a dark-mode palette
  in an unreleased indie app.

### EU and UK

- **Trade marks.** *Libertel* (C-104/01): a colour per se can be distinctive,
  but "regard must be had to the general interest in not unduly restricting the
  availability of colours for the other traders" [7]. *Heidelberger Bauchemie*
  (C-49/02): a colour combination needs "a systematic arrangement associating
  the colours concerned in a predetermined and uniform way" [8]. In the UK,
  Cadbury's purple application failed at the Court of Appeal in 2013 because its
  description was not precise enough [9].
- **Designs: the closest EU risk.** An EU design is "the appearance of the whole
  or a part of a product resulting from the features of" the product, and the
  definition lists colours. The 2024 reform (Regulation (EU) 2024/2822) says
  outright that "product" includes graphical user interfaces [10][11]. An
  **unregistered** EU design lasts three years from when it was first made
  available to the public in the EU. It stops others only where "the contested
  use results from copying" [11]. If ONE DAY has been released in the EU, an app
  whose docs say its theme was "taken from" ONE DAY gives that copying evidence
  away for free. (EUR-Lex marks Regulation 6/2002 as repealed by Regulation
  2026/715 from 30 June 2026. That looks like a consolidation. Check the
  current article numbers before relying on them.)

### App store policy

- **Apple 4.1(a) Copycats:** "Don't simply copy the latest popular app … or make
  some minor changes to another app's name or UI and pass it off as your own."
  4.1(c) bars using another developer's icon, brand or product name [12].
  Guideline 5.2.1 bars "copycat representations, names, or metadata" [12].
- **Google Play Impersonation:** apps must not "mislead users by impersonating
  someone else". Avoid "app icons, descriptions, titles, or in-app elements that
  could mislead users about your app's relationship to someone else or another
  app" [13].
- TurtleLift has its own name, icon, layout and feature set, so it is not
  impersonating ONE DAY. Store risk only arises if ONE DAY's developer
  complains. That is far more likely if the two apps look the same side by side.

## 2. What reads as copied vs generic

| Element | Reads as | Why |
|---|---|---|
| Ice → lilac "liquid" gradient on capsule buttons (`#E8ECF2 → #A9D8FF → #C9B6FF → #F4E3FF`) | **Most distinctive** | ONE DAY's signature, and the most visible thing on the main screens |
| The exact hex set (`#07080A`, `#15171C`, `#1D2027`, `#F2F4F7`, `#9EA3AE`, `#A9D8FF`, `#C9B6FF`, `#FF8A8A`) | **Copied** | Matched value for value. Only `textMuted` and `border` differ |
| Names: "liquid", "ONE DAY `ink`/`panel`/`ice`", "brushed titanium" in `app_palette.dart`, `app_theme.dart`, `app_typography.dart`, `personal_details_screen.dart`, docs, CLAUDE.md | **Evidence of copying** | Harmless on screen, but a written record of where the theme came from |
| Ice as the single cool accent on blue-black | Somewhat distinctive | Pale sky-blue on cool black is a recognisable pairing |
| Near-black page, grey surfaces, three-step grey text ramp | Generic | Every dark-mode app does this (functional, see *Apple v. Samsung*) |
| Capsule buttons, radius 16, sentence-case labels, tabular figures | Generic | Platform-standard choices |
| Danger red-pink `#FF8A8A` | Generic in kind, copied in value | Change the value along with everything else |

## 3. Original alternatives

Each option maps 1:1 onto `AppPalette`, so the swap is mechanical. All three
**drop the gradient**: the primary button becomes a solid `accentStrong`
capsule with `onAccent` text. In every option `onAccent` equals
`pageBackground`, the same trick the palette uses today, so the closed set stays at 10
distinct values plus overlays.

Contrast ratios are WCAG 2.x relative-luminance ratios, computed with a script
(not estimated). "muted" means `mutedSurface`. Accent vs `mutedSurface` is
checked against the 3:1 non-text floor (WCAG 1.4.11), because that is the
body-map fill against an untrained segment. Colour-blind separation is ΔE (CIE76)
between primary and secondary muscle after Machado 2009 full-severity
simulation. Below about 15, the two read as nearly the same colour.

### Option A: Lagoon (recommended)

Cool and calm like today, with a green-blue tint instead of steel. The turtle
link is light-touch: sea for "worked", nesting-beach sand for the secondary
muscle.

| Role | Hex |
|---|---|
| `pageBackground` | `#060A0B` |
| `surface` | `#10171A` |
| `border` | `#263236` |
| `mutedSurface` | `#172124` |
| `textPrimary` | `#EDF3F2` |
| `textSecondary` | `#9DADAC` |
| `textMuted` | `#82938F` |
| `accentStrong` | `#4FD1C5` (sea teal) |
| `accentLight` | `#CDB386` (sand, secondary muscle only) |
| `onAccent` | `#060A0B` (= page) |
| `danger` | `#FF8F80` (coral) |

Button: solid teal capsule, dark text. No gradient.

### Option B: Shell

Warm-neutral blacks and a tortoiseshell amber. This is closest to TurtleLift's
own original warm palette (`#17140F` / `#D85A30`, still in
`prototypes/screens.html`), so it is original by construction. It is less
"same line" as the current cool look.

| Role | Hex |
|---|---|
| `pageBackground` | `#0B0A08` |
| `surface` | `#181613` |
| `border` | `#302C26` |
| `mutedSurface` | `#211E1A` |
| `textPrimary` | `#F5F1EA` |
| `textSecondary` | `#ADA59A` |
| `textMuted` | `#958C80` |
| `accentStrong` | `#F2B45A` (amber) |
| `accentLight` | `#9DB6D8` (slate blue, secondary muscle only) |
| `onAccent` | `#0B0A08` (= page) |
| `danger` | `#F47C7C` |

Button: solid amber capsule. Caveat: amber and danger are fairly close for
colour-blind users (ΔE 27–30). That is fine only because danger always comes
with a text label and never appears on the body map.

### Option C: Moonlight

The most generic, and so the hardest to call a copy: neutral graphite with no
tint, and near-white as the accent. Body-map reading comes almost entirely from
lightness, which is the safest choice for colour-blind users. The trade-off: the
accent is close to `textPrimary`, so "active" leans on fill shape and weight
rather than hue, and the app has less character.

| Role | Hex |
|---|---|
| `pageBackground` | `#08090A` |
| `surface` | `#141516` |
| `border` | `#2B2D30` |
| `mutedSurface` | `#1C1E20` |
| `textPrimary` | `#F1F2F3` |
| `textSecondary` | `#A3A7AC` |
| `textMuted` | `#888D93` |
| `accentStrong` | `#E6ECF2` (moon white) |
| `accentLight` | `#7E95AB` (steel, secondary muscle only) |
| `onAccent` | `#08090A` (= page) |
| `danger` | `#FF8F80` |

Button: solid white capsule, black text.

### Contrast table

Targets: textPrimary ≥ 7, textSecondary and textMuted ≥ 4.5, onAccent on accent
≥ 4.5, accents on mutedSurface ≥ 3.

| Check | Current | Lagoon | Shell | Moonlight |
|---|---|---|---|---|
| textPrimary / page | 18.18 | 17.71 | 17.58 | 17.78 |
| textPrimary / surface | 16.27 | 16.13 | 16.04 | 16.31 |
| textSecondary / page | 7.92 | 8.53 | 8.13 | 8.24 |
| textSecondary / surface | 7.09 | 7.77 | 7.42 | 7.56 |
| textMuted / page | 5.75 | 6.17 | 5.98 | 5.96 |
| textMuted / surface | 5.15 | 5.62 | 5.45 | 5.47 |
| textMuted / mutedSurface | 4.68 | 5.10 | 5.01 | 5.00 |
| onAccent / accentStrong | 13.31 | 10.66 | 10.79 | 16.74 |
| accentStrong / mutedSurface | 10.83 | 8.80 | 9.05 | 14.05 |
| accentLight / mutedSurface | 9.02 | 8.12 | 8.00 | 5.39 |
| danger / surface | 7.90 | 8.19 | 6.90 | 8.26 |
| accentStrong vs accentLight, luminance ratio | 1.20 | 1.08 | 1.13 | 2.60 |

All options pass every target.

### Primary vs secondary muscle under colour blindness (ΔE, higher is better)

| | Current (ice/lilac) | Lagoon (teal/sand) | Shell (amber/slate) | Moonlight (white/steel) |
|---|---|---|---|---|
| Normal vision | 29.8 | 51.5 | 75.1 | 34.2 |
| Deuteranopia | **9.3** | 35.2 | 75.7 | 34.9 |
| Protanopia | 15.2 | 26.3 | 72.3 | 33.1 |
| Tritanopia | 27.2 | 62.9 | 53.7 | 34.1 |

A finding beyond the brief: **today's ice/lilac pair nearly merges for
deuteranopes** (ΔE 9.3, and only 1.20:1 in luminance). The commonest form of
colour blindness has trouble telling primary from secondary muscles on the map.
All three alternatives fix this. Lagoon and Shell do it by putting primary and
secondary on the blue–yellow axis, which red-green colour blindness keeps.
Moonlight does it with lightness.

## 4. Recommendation

**Lagoon, with a solid button.** It keeps what the owner liked (cool, dark,
quiet, one bright accent). It removes the single most recognisable borrowed
element, the iridescent gradient pill. It replaces every copied hex value and
fixes a real accessibility gap in the body map. Its turtle tie (sea and sand) is
light enough that it never becomes a costume.

Before you lock it in, screenshot it with `tool/taste_shots.sh` on both
iPhones. The teal can look slightly "fintech" in large fills. If it does, try
`#5CCFC0` or `#48C2B8` and re-run the contrast script. It sits in the
scratchpad, not the repo, so ask if you want it kept.

Separately from the palette: if ONE DAY's author did not give permission,
remove the code-level references to it. If they did, record that permission
somewhere in the repo.

## 5. Swap checklist (not done here)

1. `lib/src/theme/app_palette.dart`: replace the 11 values and rewrite the doc
   comments to drop every "ONE DAY `x`" reference and "brushed titanium".
   Delete `AppGradients` (or keep the class empty only if something must import
   it; nothing should).
2. `lib/src/theme/app_theme.dart`: remove `_liquidBackground` and the
   `.copyWith(backgroundBuilder: _liquidBackground)` on the primary button
   (around line 137). The solid `backgroundColor: AppPalette.accentStrong` underneath
   already does the job. Update the §12 quote comment at line 16 and the
   "liquid metal" comment at line 125.
3. `lib/src/ui/personal_details_screen.dart` (~line 275): uses
   `AppGradients.liquid` directly. Switch it to a solid `accentStrong` fill.
   Also update the "ice outline" comment at ~197.
4. `lib/src/ui/profile_root.dart:104` ("ice slab") and
   `lib/src/theme/app_typography.dart:23` ("ONE DAY's eyebrow"): comment
   wording only.
5. `lib/src/ui/glass_tab_bar.dart:200,212`: the word "liquid" there describes
   motion, not the gradient. Optional rename.
6. `test/theme_palette_test.dart`: the closed set uses `AppPalette.*` symbols, so
   values follow on their own. Fix the comment at line 27 ("ONE DAY `ink`"). If
   `onAccent` ever stops equalling `pageBackground`, add it to the set.
7. `docs/00-build-spec.md` §12 (lines ~250–272) and the fill colours at lines
   117 and 180: new hexes. Delete the "Gradient (one): liquid" line.
8. `docs/01-app-idea.md` "Visual theme" section (~line 400) and its palette and
   usage tables: new hexes, delete the liquid sentence and the ONE DAY
   attribution. Note: the heading still says "Coral" while the body describes
   titanium. That is an existing inconsistency to fix in the same edit.
9. `CLAUDE.md`: the "Palette is ONE DAY's cool titanium" bullet, plus the
   `textMuted` and `#FF8A8A` mentions in the taste-pass and destructive-action
   bullets.
10. `.claude/skills/turtle-taste/SKILL.md:25`: "The liquid gradient = primary
    buttons only." Remove it, or replace it with "no gradients".
11. `docs/open-points.md` items 4–5: close or rewrite them, since both concern
    ONE DAY.
12. `docs/one-day-theme-reference.md`: delete it. It is the main written record
    of copying and is no longer the source of anything. If its general lessons
    are worth keeping (grey hierarchy, one accent), restate them without ONE DAY
    in a new ADR (`docs/adr/`) recording the palette change.
13. `prototypes/screens.html` still uses the original warm palette. It is a
    layout reference, so leave it, or update its `:root` variables if you want
    it to match.

## Sources

1. 37 CFR 202.1, Material not subject to copyright: https://www.law.cornell.edu/cfr/text/37/202.1
2. 15 U.S.C. §1125 (Lanham Act §43): https://www.law.cornell.edu/uscode/text/15/1125
3. *Wal-Mart Stores v. Samara Bros.*, 529 U.S. 205 (2000): https://www.law.cornell.edu/supct/html/99-150.ZS.html
4. *Apple Inc. v. Samsung Electronics Co.*, 786 F.3d 983 (Fed. Cir. 2015), opinion text: https://www.bitlaw.com/source/cases/patent/Apple_v_Samsung_Fed_Cir.html
5. *Qualitex Co. v. Jacobson Products Co.*, 514 U.S. 159 (1995): https://www.law.cornell.edu/supremecourt/text/514/159
6. *Christian Louboutin S.A. v. Yves Saint Laurent America*, 696 F.3d 206 (2d Cir. 2012), FindLaw summary (full opinion was not retrieved): https://caselaw.findlaw.com/summary/opinion/us-2nd-circuit/2012/09/05/260108.html
7. CJEU, *Libertel Groep v. Benelux-Merkenbureau*, C-104/01: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:62001CJ0104
8. CJEU, *Heidelberger Bauchemie*, C-49/02: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:62002CJ0049
9. *Société des Produits Nestlé v. Cadbury UK* [2013] EWCA Civ 1174, transcript on WIPO Lex: https://www.wipo.int/wipolex/es/text/594030
10. EUR-Lex summary of the EU design reform (Regulation (EU) 2024/2822): https://eur-lex.europa.eu/EN/legal-content/summary/european-union-designs.html
11. Council Regulation (EC) No 6/2002 on Community designs, Arts 3, 11, 19: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32002R0006
12. Apple App Store Review Guidelines, 4.1 and 5.2.1: https://developer.apple.com/app-store/review/guidelines/
13. Google Play Impersonation policy: https://support.google.com/googleplay/android-developer/answer/9888374
