# Prototypes

Reference only. **Not production code, not a design system.** Open each in a browser;
nothing to install.

| File | Question it answers |
|---|---|
| `app-flow.html` | What does the app feel like? One flow, fully interactive: splash → template → muscle → exercise → log → finish. Real traced SVGs, real state. |
| `session-logic.html` | Does the state model hold up? Pure reducer plus guided walkthroughs for the awkward cases — abandoned sessions, backdating, inverted assisted PBs. The module inside is meant to be rewritten in Dart. |
| `screens.html` | 22 static screens covering the whole app. Layout reference. |

Where these disagree with `docs/`: **on layout, the prototypes win** (they are newer).
**On rules, the docs win.**

These are throwaway artifacts kept as primary sources. Delete them once the app is built
and the decisions live in code.
