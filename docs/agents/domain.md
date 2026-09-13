# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

**This repo is single-context.** One `CONTEXT.md` and one `docs/adr/` at the root.
There is no `CONTEXT-MAP.md` and there should not be one — this is a single Flutter
app, not a monorepo.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root
- **`docs/adr/`**: read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

As of this writing neither exists yet. That is the expected state, not a gap to fill.

## File structure

```
/
├── CONTEXT.md
├── docs/
│   ├── 00-build-spec.md … 05-mascot-brief.md   ← the product spec (not ADRs)
│   ├── adr/
│   │   ├── 0001-riverpod-and-drift.md
│   │   └── 0002-derive-everything-on-read.md
│   └── agents/                                 ← this directory
└── lib/
```

Note `lib/`, not `src/` — this is a Flutter project.

## The spec is not the domain docs

`docs/00`–`05` are the product specification and they already carry a conflict
order of their own: `01`–`04` beat `00`, and `prototypes/` beats the docs on
layout. ADRs under `docs/adr/` are a **separate** record — they capture technical
decisions and their rationale, not product rules. Don't merge the two, and don't
treat a spec statement as an ADR.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

This repo already has load-bearing vocabulary worth respecting: `performedOn` vs
`loggedAt`, `loadType`, `trained`, "derived values", "the four load types".

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
