#!/usr/bin/env python3
"""
validate_exercise_library.py — validates EXERCISES against muscle_taxonomy.json
and emits exercises.json + exercises.csv + a coverage report.

Fails the build on: unknown muscle id, duplicate name, duplicate slug,
empty/oversized primary list, a muscle in both primary and secondary,
unknown equipment, or a sub-muscle group with no exercises.
"""
import csv, json, re, sys
from collections import defaultdict
from pathlib import Path
from exercise_library import EXERCISES, EQUIPMENT, LOAD_TYPES
import content_chest, content_back, content_shoulders_biceps, content_arms_core, content_legs

CONTENT = {}
for _m in (content_chest, content_back, content_shoulders_biceps, content_arms_core, content_legs):
    for _k, _v in _m.CONTENT.items():
        if _k in CONTENT:
            raise SystemExit(f"duplicate content entry: {_k!r}")
        CONTENT[_k] = _v
CONTENT_FIELDS = ("setup", "posture", "execution", "commonMistakes")

MIN_PER_SUB, MIN_EQUIP_PER_SUB, MAX_PRIMARY = 4, 2, 3


def slug(name):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", name.lower())).strip("-")


def main(src=".", out="."):
    tax = json.loads((Path(src) / "muscle_taxonomy.json").read_text())
    valid = set(tax["subMuscleGroups"])
    errors, warnings = [], []

    seen_name, seen_slug = {}, {}
    rows = []
    for name, equip, load, prim, sec in EXERCISES:
        s = slug(name)
        if name in seen_name:
            errors.append(f"duplicate name: {name!r}")
        if s in seen_slug:
            errors.append(f"duplicate slug {s!r}: {name!r} vs {seen_slug[s]!r}")
        seen_name[name] = seen_slug[s] = name

        if equip not in EQUIPMENT:
            errors.append(f"{name}: unknown equipment {equip!r}")
        if load not in LOAD_TYPES:
            errors.append(f"{name}: unknown loadType {load!r}")
        if equip == "bodyweight" and load in ("weighted", "assisted"):
            errors.append(f"{name}: bodyweight equipment cannot have loadType {load!r}")
        if load == "assisted" and not name.lower().startswith("assisted"):
            warnings.append(f"{name}: loadType 'assisted' but name doesn't say so")
        if not prim:
            errors.append(f"{name}: empty primary list")
        if len(prim) > MAX_PRIMARY:
            errors.append(f"{name}: {len(prim)} primary muscles (max {MAX_PRIMARY})")
        for m in prim + sec:
            if m not in valid:
                errors.append(f"{name}: unknown muscle id {m!r}")
        overlap = set(prim) & set(sec)
        if overlap:
            errors.append(f"{name}: {sorted(overlap)} listed as both primary and secondary")

        c = CONTENT.get(name)
        if c is None:
            errors.append(f"{name}: no content entry")
            c = ("", "", "", "")
        elif len(c) != 4:
            errors.append(f"{name}: content has {len(c)} fields, expected 4")
            c = (list(c) + ["", "", "", ""])[:4]
        for fname, text in zip(CONTENT_FIELDS, c):
            if not text.strip():
                errors.append(f"{name}: empty {fname}")
            elif len(text.split()) > 60:
                warnings.append(f"{name}: {fname} is {len(text.split())} words (target <= 60)")
        rows.append({"id": s, "name": name, "equipment": equip, "loadType": load,
                     "primary": prim, "secondary": sec,
                     **dict(zip(CONTENT_FIELDS, c))})

    by_prim, equip_by_prim = defaultdict(list), defaultdict(set)
    for r in rows:
        for m in r["primary"]:
            by_prim[m].append(r["name"])
            equip_by_prim[m].add(r["equipment"])

    for sub in sorted(valid):
        n, e = len(by_prim[sub]), len(equip_by_prim[sub])
        if n == 0:
            errors.append(f"{sub}: NO exercises list it as primary")
        elif n < MIN_PER_SUB:
            warnings.append(f"{sub}: only {n} exercises (target >= {MIN_PER_SUB})")
        if 0 < e < MIN_EQUIP_PER_SUB:
            warnings.append(f"{sub}: only {e} equipment type(s) (target >= {MIN_EQUIP_PER_SUB})")

    for cname in CONTENT:
        if cname not in seen_name:
            errors.append(f"content entry {cname!r} matches no exercise")

    if errors:
        print("VALIDATION FAILED\n  " + "\n  ".join(errors)); sys.exit(1)

    Path(out, "exercises.json").write_text(json.dumps(rows, indent=2) + "\n")
    with open(Path(out, "exercises.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "name", "equipment", "loadType", "primary", "secondary",
                    "setup", "posture", "execution", "commonMistakes"])
        for r in rows:
            w.writerow([r["id"], r["name"], r["equipment"], r["loadType"],
                        "; ".join(r["primary"]), "; ".join(r["secondary"]),
                        r["setup"], r["posture"], r["execution"], r["commonMistakes"]])

    from collections import Counter as _C
    lt = _C(r["loadType"] for r in rows)
    print(f"OK  {len(rows)} exercises, 0 errors, {len(warnings)} warnings")
    print(f"    loadType: " + ", ".join(f"{k}={lt[k]}" for k in LOAD_TYPES) + "\n")
    if warnings:
        print("warnings:\n  " + "\n  ".join(warnings) + "\n")
    print(f"{'sub-muscle group':<26}{'as primary':>11}{'equip':>7}   {'as secondary':>12}")
    sec_count = defaultdict(int)
    for r in rows:
        for m in r["secondary"]:
            sec_count[m] += 1
    for g, meta in tax["parents"].items():
        for sub in meta["subs"]:
            k = f"{g}/{sub}"
            print(f"{k:<26}{len(by_prim[k]):>11}{len(equip_by_prim[k]):>7}   {sec_count[k]:>12}")


if __name__ == "__main__":
    main(*sys.argv[1:])
