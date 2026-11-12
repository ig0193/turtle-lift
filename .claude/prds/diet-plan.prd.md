# Diet Plan — weekly high-protein meals with reminders

> **Status: accepted; placement superseded by `docs/adr/0007-diet-in-profile.md`.**
> Diet is the third Profile segment (Personal | Schedule | Diet), **not a fifth
> tab**. Plan: `docs/plans/2026-11-08-1702-feat-diet-weekly-protein-plan.md`.

## Problem
People who train, both regular lifters and beginners, often don't eat enough
protein to recover and build muscle. They don't know which everyday foods are
high in protein, and they don't plan meals ahead. Vegetarians are hit hardest.
TurtleLift already records what they lift but says nothing about what they eat,
so they need a second app. Most diet apps are built around logging calories,
and users drop them because logging takes too long.

## Evidence
- **Protein shortfall is widespread among likely users.** A Feb 2026 survey of
  2 lakh+ urban Indian respondents (LocalCircles × Country Delight) found
  **6 in 10 don't meet their daily protein requirement**
  ([ETV Bharat](https://www.etvbharat.com/en/health/survey-urban-indians-protein-deficient-enn26020602237),
  [The Wire](https://m.thewire.in/article/ptiprnews/indias-protein-gap-a-survey-by-localcircles-country-delight-reveals-60-of-urban-india-is-protein-deficient)).
  Older studies put it at 63–73%
  ([Sentinel](https://sentinelassam.com/life/63-indians-consume-insufficient-protein-in-daily-diet),
  [BioVoice](https://biovoicenews.com/study-reveals-lucknow-most-protein-deficient-at-90-delhi-at-60/)).
  Caveat: these surveys were mostly sponsored by food companies, and they don't
  define "deficient" the same way.
- **Vegetarians are worst affected:** 84% had a protein-deficient diet, against
  73% overall
  ([BioVoice](https://biovoicenews.com/study-reveals-lucknow-most-protein-deficient-at-90-delhi-at-60/)).
  This supports a dedicated **Veg** filter.
- **People don't know what they need.** Over 90% were unaware of their daily
  protein requirement (PRODIGY 2015,
  [ORF](https://www.orfonline.org/expert-speak/indias-protein-deficiency-and-the-need-to-address-the-problem)).
  This supports showing a **daily target** and **grams per serving**.
- **Logging effort kills diet apps.** The top reason users quit a nutrition app
  was the time it takes (37%,
  [Wageningen](https://edepot.wur.nl/636781)). This supports a plan that takes a
  few minutes once a week, not food logging after every meal.
- **Athletes want meal reminders.** In a survey of athletes, respondents
  preferred in-app alerts and meal reminders
  ([LSU / PBRC](https://repository.lsu.edu/pbrc_basic_science_pubs/169)).
- **Lifters want workouts and nutrition in one place.** One example: a
  Cronometer user said they would leave Strong if the nutrition app could log
  sets and reps
  ([Cronometer forum](https://forums.cronometer.com/discussion/5881/please-add-reps-sets-as-tracking-criteria)).
  This is anecdotal, and no study measures demand for one gym-and-diet app.
- **Reminders measurably improving adherence:** *Assumption — needs validation
  via prototype / user feedback.* The only result found was a weak pre/post
  study (meal-plan adherence 48% → 60%), and a randomised trial on meal-logging
  reminders hasn't reported yet
  ([NCT07555262](https://clinicaltrials.gov/study/NCT07555262)).
- **TurtleLift users specifically wanting this:** *Assumption — needs validation
  via prototype / user feedback.* No requests from the app's own users yet.

## Users
- **Primary: the regular lifter.** Trains several times a week and knows protein
  matters. Doesn't hit their target because meals aren't planned. Triggered by
  stalled progress or by setting a goal.
- **Primary: the beginner.** Just started training and doesn't know which foods
  are high in protein or how much they need. Triggered by starting to use the
  app.
- **Not for:** people tracking calories or every macro, clinical or medical diets
  (diabetes, kidney disease, allergies), or anyone who wants a meal plan written
  for them.

## Hypothesis
We believe that **a weekly high-protein meal plan (Veg / Non-veg / Egg) with a
daily protein target and opt-in meal-time reminders** will **help lifters and
beginners eat enough protein without a second app** for **TurtleLift users who
train regularly**.
We'll know we're right when **users who set up a plan keep it filled for at
least 5 days a week and keep reminders on for at least 2 weeks**.

## Success Metrics
The app is offline and local-only, with no analytics, so none of these can be
measured automatically. Each one comes from asking users directly.

| Metric | Target | How measured |
|---|---|---|
| Plan coverage | ≥ 5 of 7 days have at least one meal planned | TBD — needs validation via user interviews or screenshots from testers |
| Reminder retention | Reminders still on after 2 weeks for ≥ 50% of people who opted in | TBD — needs validation via tester check-ins |
| Days the plan reaches the target | Most planned days reach the daily target | TBD — needs validation via testers |
| Perceived value | Testers say they would keep using it | User interviews / store reviews |

## Scope
**MVP**
- A built-in, offline catalogue of high-protein foods. Each food has a serving
  size and grams of protein per serving, and the catalogue filters by **Veg /
  Non-veg / Egg**.
- A **weekly plan**: for each weekday, add foods to **Breakfast / Lunch /
  Snack / Dinner**. The same plan repeats every week.
- A **daily protein target** (the user sets it, or the app suggests one from the
  bodyweight it already stores). Each day shows a running total against the
  target.
- **Mark as eaten (optional):** one tap per meal. The day's total then shows
  protein eaten against planned and the target.
- ~~Lives in a **new 5th tab, Diet**.~~ Superseded by ADR 0007: lives in the
  **Diet segment of the Profile tab**.
- **Opt-in local notifications**, under the same rules as ADR 0005:
  - Permission is asked for only when the user turns reminders on, after a
    sheet that explains them.
  - A **morning summary** of the day's meals and total protein, at a time the
    user chooses.
  - A **meal-time reminder** naming the food and the protein it gives. Each meal
    has one time that applies to every day.
  - Reminders never react to what the user did: no "you skipped lunch", and no
    wording that changes after a gap.

**Out of scope**
- Calories, carbs and fat — the feature is about protein, and tracking all
  macros is what other apps already do.
- Custom foods, barcode scanning, recipes and food photos — each adds logging
  effort, which is the top reason people quit diet apps.
- AI-generated meal plans — the app has no AI features, by rule.
- Shopping lists, grocery delivery and supplement selling.
- A premium paywall — `CLAUDE.md` rules out a premium tier for V1.
- Medical or clinical diets and allergy handling.
- Notifications that react to behaviour (missed meals, streaks at risk).

## Delivery Milestones
| # | Milestone | Outcome | Status | Plan |
|---|---|---|---|---|
| 1 | Requirements and ADR | This PRD is approved, and an ADR extends ADR 0005's notification exception to meal reminders | pending | — |
| 2 | App flow | The screen-by-screen flow is agreed, including where Diet lives in the navigation | pending | — |
| 3 | Prototype | Diet screens are added to `prototypes/screens.html` and reviewed | pending | — |
| 4 | Food catalogue | A generated, validated list of protein foods ships offline | pending | — |
| 5 | Weekly plan and target | The user can build a weekly plan and see daily totals against the target | pending | — |
| 6 | Reminders | The morning summary and meal-time reminders work, opt-in | pending | — |

## Open Questions
- [x] **Plan only, or also mark as eaten?** → **Planned, plus an optional tick.**
  Each day shows protein planned against the target. One tap marks a meal as
  eaten, and the day then shows protein eaten against planned. A tick belongs to
  a calendar date. Editing the plan never rewrites past weeks (as ADR 0005 does).
- [x] **Snack slot?** → **Yes: Breakfast / Lunch / Snack / Dinner.** The snack
  reminder is optional.
- [ ] **Where the protein values come from, and who reviews them.** For example,
  IFCT 2017 (NIN, India) or USDA. Wrong numbers mislead users, so this content
  needs the same care as the exercise copy.
- [x] **What the catalogue covers.** → **Indian foods first, in household units**
  (katori / pieces / glass), with grams shown. Values from IFCT 2017 (NIN), each
  food citing its source.
- [ ] **How the target is suggested.** Which g/kg multiplier, and does it change
  between beginner and regular lifter? It needs a cited source.
- [x] **Where Diet lives.** → ~~**A new 5th tab.**~~ **Superseded: a third
  Profile segment** (ADR 0007), keeping ADR 0004's four-tab ceiling.
- [ ] **One plan for all weeks, or different on training and rest days?**
- [ ] **Egg filter.** Does "Egg" mean egg-only foods, or vegetarian foods plus
  eggs? (In India, an eggetarian eats vegetarian food and eggs.)
- [ ] **Medical disclaimer.** What wording, and where does it appear?

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Wrong protein values mislead users | Medium | High | One cited source per food; a validator checks the data like `exercises.json` |
| Scope creep into a full diet app (calories, recipes) | High | Medium | Explicit out-of-scope list; protein only |
| Notifications feel like nagging and get turned off | Medium | Medium | Opt-in, fixed schedule, never react to behaviour, one switch per meal |
| Success can't be measured (no analytics) | High | Medium | Tester interviews; consider an opt-in feedback prompt later |
| Adding a tab breaks the navigation ADRs | Medium | Medium | Decide in the app-flow milestone and record it in an ADR |
| Users read it as medical advice | Low | High | Disclaimer; no clinical claims |

---
*Status: accepted (ADR 0007); placement superseded — Profile segment, not a fifth
tab. Implementation plan: `docs/plans/2026-11-08-1702-feat-diet-weekly-protein-plan.md`.*
