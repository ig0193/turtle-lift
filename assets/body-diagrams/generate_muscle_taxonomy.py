#!/usr/bin/env python3
"""
generate_muscle_taxonomy.py

Single source of truth for the app's muscle taxonomy and for how each
sub-muscle group maps onto segments in the body-diagram SVGs.

Emits muscle_taxonomy.json, muscle_taxonomy.dart and muscle_taxonomy.md,
and validates all three against the actual SVG assets so the taxonomy and
the artwork cannot drift apart.

SEGMENT RESOLUTION RULE
  Default: sub-muscle group "<group>/<sub>" maps to every SVG segment
  carrying data-muscle-group="<group>" and data-sub-muscle-group="<sub>",
  in whichever view(s) that segment exists. Several sub-groups legitimately
  resolve to both views (forearms, calves, upper back).

  Exactly ONE exception exists -- see MAP_OVERRIDES below.
"""

import json
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------- taxonomy
# parent group -> (parent label, [(sub id, sub label), ...])
TAXONOMY = {
    "chest":      ("Chest",      [("upper", "Upper chest"), ("mid", "Mid chest"), ("lower", "Lower chest")]),
    "back":       ("Back",       [("upper", "Upper back & traps"), ("lats", "Lats"), ("lower", "Lower back")]),
    "shoulders":  ("Shoulders",  [("front-delt", "Front delt"), ("side-delt", "Side delt"), ("rear-delt", "Rear delt")]),
    "biceps":     ("Biceps",     [("biceps", "Biceps")]),
    "triceps":    ("Triceps",    [("triceps", "Triceps")]),
    "forearms":   ("Forearms",   [("forearms", "Forearms")]),
    "abs":        ("Abs",        [("upper", "Upper abs"), ("lower", "Lower abs")]),
    "obliques":   ("Obliques",   [("obliques", "Obliques")]),
    "quads":      ("Quads",      [("quads", "Quads")]),
    "hamstrings": ("Hamstrings", [("hamstrings", "Hamstrings")]),
    "glutes":     ("Glutes",     [("glutes", "Glutes")]),
    "calves":     ("Calves",     [("calves", "Calves")]),
}

# The ONLY sub-muscle group without its own artwork.
# The traced "front delt" shape reaches the outer edge of the shoulder at
# shoulder height, so it depicts the whole visible shoulder cap from the
# front -- which physically includes the side delt's front-facing surface.
# Mapped to the FRONT view only: mapping it to rear-delt as well would make
# a lateral raise appear to have trained the rear delt when the user flips
# the diagram. Resolve with a real segment once 3/4-angle art exists.
MAP_OVERRIDES = {
    "shoulders/side-delt": [("front", "shoulders/front-delt")],
}

VIEWS = {"front": ["body-diagram-front.svg", "body-diagram-front-female.svg"],
         "back":  ["body-diagram-back.svg",  "body-diagram-back-female.svg"]}

GROUP = re.compile(r'<g\b([^>]*class="muscle-segment"[^>]*)>', re.S)
ATTR = re.compile(r'([\w-]+)="([^"]*)"')


def segments_in(svg):
    out = set()
    for m in GROUP.finditer(Path(svg).read_text()):
        a = dict(ATTR.findall(m.group(1)))
        out.add(f'{a["data-muscle-group"]}/{a["data-sub-muscle-group"]}')
    return out


def main(src_dir=".", out_dir="."):
    src_dir, out_dir = Path(src_dir), Path(out_dir)

    present = {}
    for view, files in VIEWS.items():
        sets = [segments_in(src_dir / f) for f in files]
        if sets[0] != sets[1]:
            raise SystemExit(f"{view}: male/female segment sets differ -> {sets[0] ^ sets[1]}")
        present[view] = sets[0]

    resolved, claimed, errors = {}, set(), []
    for group, (glabel, subs) in TAXONOMY.items():
        for sub, slabel in subs:
            key = f"{group}/{sub}"
            if key in MAP_OVERRIDES:
                segs = MAP_OVERRIDES[key]
                note = "no artwork of its own; shares another segment"
            else:
                segs = [(v, key) for v in ("front", "back") if key in present[v]]
                note = None
            if not segs:
                errors.append(f"{key}: resolves to no SVG segment in either view")
            for v, s in segs:
                if s not in present[v]:
                    errors.append(f"{key}: mapped to {s} in {v} view, which has no such segment")
                claimed.add((v, s))
            resolved[key] = {
                "group": group, "groupLabel": glabel, "sub": sub, "label": slabel,
                "segments": [{"view": v, "segment": s} for v, s in segs],
                "note": note,
            }

    for v, segs in present.items():
        for s in segs:
            if (v, s) not in claimed:
                errors.append(f"orphan: {v} view has segment {s}, claimed by no sub-muscle group")

    if errors:
        raise SystemExit("TAXONOMY VALIDATION FAILED\n  " + "\n  ".join(errors))

    data = {
        "parents": {g: {"label": l, "subs": [s for s, _ in subs]} for g, (l, subs) in TAXONOMY.items()},
        "subMuscleGroups": resolved,
    }
    (out_dir / "muscle_taxonomy.json").write_text(json.dumps(data, indent=2) + "\n")

    # ---- Dart ----
    d = ["// GENERATED FILE -- do not edit by hand.",
         "// Produced by generate_muscle_taxonomy.py; validated against the SVG assets.",
         "",
         "class SubMuscleGroup {",
         "  final String id, group, label;",
         "  final List<({String view, String segment})> segments;",
         "  const SubMuscleGroup(this.id, this.group, this.label, this.segments);",
         "}", "",
         "/// Parent muscle group -> ordered sub-muscle group ids.",
         "/// Templates store PARENT ids only; rows are derived from this map.",
         "const Map<String, List<String>> kMuscleTaxonomy = {"]
    for g, (l, subs) in TAXONOMY.items():
        d.append(f"  '{g}': [{', '.join(repr(s) for s, _ in subs)}],".replace("'", "'"))
    d += ["};", "", "const Map<String, String> kMuscleGroupLabels = {"]
    for g, (l, _) in TAXONOMY.items():
        d.append(f"  '{g}': '{l}',")
    d += ["};", "",
          "/// Sub-muscle group -> display label and the diagram segment(s) it fills.",
          "const Map<String, SubMuscleGroup> kSubMuscleGroups = {"]
    for key, r in resolved.items():
        segs = ", ".join("(view: '%s', segment: '%s')" % (s["view"], s["segment"]) for s in r["segments"])
        d.append(f"  '{key}': SubMuscleGroup('{key}', '{r['group']}', '{r['label']}', [{segs}]),")
    d += ["};", ""]
    (out_dir / "muscle_taxonomy.dart").write_text("\n".join(d))

    # ---- Markdown (for the spec docs; same source, so it cannot disagree) ----
    m = ["| Parent | Sub-muscle group | Diagram segment(s) filled | Note |",
         "|---|---|---|---|"]
    for key, r in resolved.items():
        segs = "<br>".join(f"`{s['view']}` → `{s['segment']}`" for s in r["segments"])
        m.append(f"| {r['groupLabel']} | **{r['label']}** (`{key}`) | {segs} | {r['note'] or ''} |")
    (out_dir / "muscle_taxonomy.md").write_text("\n".join(m) + "\n")

    n_sub = len(resolved)
    n_parent = len(TAXONOMY)
    single = [g for g, (_, s) in TAXONOMY.items() if len(s) == 1]
    print(f"OK  {n_parent} parent groups, {n_sub} sub-muscle groups, "
          f"{len(MAP_OVERRIDES)} mapping exception, 0 orphan segments")
    print(f"    single-sub parents (render as one flat row, no accordion): {', '.join(single)}")


if __name__ == "__main__":
    main(*sys.argv[1:])
