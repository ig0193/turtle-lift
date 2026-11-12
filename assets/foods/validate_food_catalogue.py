#!/usr/bin/env python3
"""
validate_food_catalogue.py -- validates the food source tables (foods_*.py)
and emits foods.json (shipped in the app) + foods.csv (for the owner's review).

    python3 validate_food_catalogue.py                  # CI: validate, emit
    python3 validate_food_catalogue.py --update-ledger  # also record new ids

Fails on: duplicate id or name (names compared case-insensitively); id not
lower-case-hyphen; missing field; dietType outside the enum; proteinPer100g
<= 0 or > 100; gramsPerServing not a positive integer; protein per serving
above grams per serving; empty ifctCode, servingLabel, servingSource or
reviewedBy; any id in food_ids_ever.csv missing from the rows (R8); a ledger
id whose dietType changed; an id the ledger has never recorded (re-run with
--update-ledger); counts under the A10 minimums; an IFCT egg entry no egg
row carries.

The ledger is append-only and changes only with --update-ledger, which CI
never passes. A food id, once shipped, is never removed or reused.
"""
import csv
import json
import re
import sys
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

from food_catalogue import DIET_TYPES, IFCT_EGG_CODES, MINIMUMS, NOT_IN_IFCT
import foods_dairy, foods_pulses, foods_grains_nuts, foods_vegetables, foods_egg, foods_meat_fish

FAMILIES = (foods_dairy, foods_pulses, foods_grains_nuts, foods_vegetables, foods_egg, foods_meat_fish)

HERE = Path(__file__).resolve().parent
LEDGER = "food_ids_ever.csv"

SOURCE_FIELDS = ("id", "name", "aliases", "dietType", "ifctCode", "ifctPage",
                 "proteinPer100g", "servingLabel", "gramsPerServing",
                 "servingSource", "reviewedBy", "reviewNote")

# foods.json, in this order. servingSource, ifctPage and reviewNote are review
# material and stay in foods.csv.
JSON_FIELDS = ("id", "name", "aliases", "dietType", "servingLabel",
               "gramsPerServing", "proteinPerServingG", "proteinPer100g",
               "ifctCode", "reviewedBy")

CSV_FIELDS = ("id", "name", "aliases", "dietType", "servingLabel",
              "gramsPerServing", "servingSource", "proteinPer100g",
              "proteinPerServingG", "ifctCode", "ifctPage", "reviewedBy",
              "reviewNote")

ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def load_rows():
    rows = []
    for fam in FAMILIES:
        rows.extend(fam.FOODS)
    return rows


def read_ledger(path):
    path = Path(path)
    if not path.exists():
        return {}
    with open(path, newline="") as f:
        return {r["id"]: r["dietType"] for r in csv.DictReader(f)}


def write_ledger(path, ledger):
    with open(path, "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["id", "dietType"])
        for i in sorted(ledger):
            w.writerow([i, ledger[i]])


def _number(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool)


def _text(x):
    return isinstance(x, str) and x.strip() != ""


def per_serving(p100, grams):
    """Protein per serving, one decimal, half-up -- stable across platforms."""
    q = Decimal(str(p100)) * Decimal(grams) / Decimal(100)
    return float(q.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP))


def counts(foods):
    c = {"total": len(foods)}
    for d in DIET_TYPES:
        c[d] = sum(1 for f in foods if f["dietType"] == d)
    return c


def check(rows, ledger, minimums=MINIMUMS, egg_codes=IFCT_EGG_CODES,
          require_ledger=False):
    """Returns (errors, foods). foods are sorted by id and carry the
    review-only fields (foods.csv) under a leading underscore."""
    errors = []
    seen_id, seen_name = set(), {}
    foods = []

    for r in rows:
        fid = r.get("id", "<no id>")
        missing = [k for k in SOURCE_FIELDS if k not in r]
        if missing:
            errors.append(f"{fid}: missing field(s) {', '.join(missing)}")
            continue
        extra = sorted(set(r) - set(SOURCE_FIELDS))
        if extra:
            errors.append(f"{fid}: unknown field(s) {', '.join(extra)}")

        if not isinstance(fid, str) or not ID_RE.match(fid):
            errors.append(f"{fid!r}: id must be lower-case-hyphen (a-z, 0-9, single hyphens)")
        if fid in seen_id:
            errors.append(f"duplicate id: {fid!r}")
        seen_id.add(fid)

        name = r["name"]
        if not _text(name):
            errors.append(f"{fid}: empty name")
        else:
            key = name.strip().lower()
            if key in seen_name:
                errors.append(f"duplicate name {name!r}: {fid} vs {seen_name[key]}")
            seen_name[key] = fid

        aliases = r["aliases"]
        if not isinstance(aliases, list) or not all(_text(a) for a in aliases):
            errors.append(f"{fid}: aliases must be a list of non-empty strings")
            aliases = []

        if r["dietType"] not in DIET_TYPES:
            errors.append(f"{fid}: dietType {r['dietType']!r} not in {DIET_TYPES}")

        for k in ("ifctCode", "servingLabel", "servingSource", "reviewedBy"):
            if not _text(r[k]):
                errors.append(f"{fid}: empty {k}")

        page = r["ifctPage"]
        if page is not None and not (isinstance(page, int) and not isinstance(page, bool) and page > 0):
            errors.append(f"{fid}: ifctPage must be a positive integer or None")
        if not isinstance(r["reviewNote"], str):
            errors.append(f"{fid}: reviewNote must be a string")

        p100, grams = r["proteinPer100g"], r["gramsPerServing"]
        p_ok = _number(p100) and 0 < p100 <= 100
        g_ok = isinstance(grams, int) and not isinstance(grams, bool) and grams > 0
        if not p_ok:
            errors.append(f"{fid}: proteinPer100g {p100!r} must be > 0 and <= 100")
        if not g_ok:
            errors.append(f"{fid}: gramsPerServing {grams!r} must be a positive integer")
        ps = None
        if _number(p100) and g_ok:
            ps = per_serving(p100, grams)
            if ps > grams:
                errors.append(f"{fid}: protein per serving {ps} g exceeds gramsPerServing {grams} g")

        foods.append({
            "id": fid, "name": name, "aliases": aliases, "dietType": r["dietType"],
            "servingLabel": r["servingLabel"], "gramsPerServing": grams,
            "proteinPerServingG": ps,
            "proteinPer100g": float(p100) if _number(p100) else p100,
            "ifctCode": r["ifctCode"], "reviewedBy": r["reviewedBy"],
            "_servingSource": r["servingSource"], "_ifctPage": page,
            "_reviewNote": r["reviewNote"],
        })

    # R8: the ledger.
    by_id = {f["id"]: f for f in foods}
    for lid in sorted(ledger):
        if lid not in by_id:
            errors.append(f"removed id: {lid!r} is in {LEDGER} but not in the rows (ids are never removed)")
        elif by_id[lid]["dietType"] != ledger[lid]:
            errors.append(f"{lid}: dietType changed from {ledger[lid]!r} to "
                          f"{by_id[lid]['dietType']!r} (the ledger pins it)")
    if require_ledger:
        for fid in sorted(set(by_id) - set(ledger)):
            errors.append(f"{fid}: not in {LEDGER}; re-run with --update-ledger to record it")

    # A10: minimums and egg coverage.
    c = counts(foods)
    for k, need in minimums.items():
        if c.get(k, 0) < need:
            errors.append(f"{k} count {c.get(k, 0)} is under the minimum {need}")
    egg_carried = {f["ifctCode"] for f in foods if f["dietType"] == "egg"}
    for code in egg_codes:
        if code not in egg_carried:
            errors.append(f"IFCT egg entry {code} is carried by no egg row")

    foods.sort(key=lambda f: f["id"])
    return errors, foods


def validate(rows, ledger, **kw):
    """Returns (errors, foods): foods exactly as foods.json carries them, sorted by id."""
    errors, foods = check(rows, ledger, **kw)
    return errors, [{k: f[k] for k in JSON_FIELDS} for f in foods]


def emit(foods, out):
    out = Path(out)
    public = [{k: f[k] for k in JSON_FIELDS} for f in foods]
    (out / "foods.json").write_text(json.dumps(public, indent=2, ensure_ascii=False) + "\n",
                                    encoding="utf-8")
    with open(out / "foods.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(CSV_FIELDS)
        for f in foods:
            row = dict(f, servingSource=f["_servingSource"],
                       ifctPage="" if f["_ifctPage"] is None else f["_ifctPage"],
                       reviewNote=f["_reviewNote"], aliases="; ".join(f["aliases"]))
            w.writerow([row[k] for k in CSV_FIELDS])


def main(argv):
    update = "--update-ledger" in argv
    quiet = "--quiet" in argv
    out = HERE
    if "--out" in argv:
        out = Path(argv[argv.index("--out") + 1])

    ledger_path = HERE / LEDGER
    ledger = read_ledger(ledger_path)
    rows = load_rows()

    # With --update-ledger, unrecorded ids are fine: they are about to be recorded.
    errors, foods = check(rows, ledger, require_ledger=not update)
    if errors:
        print("VALIDATION FAILED\n  " + "\n  ".join(errors))
        return 1

    if update:
        new = {f["id"]: f["dietType"] for f in foods if f["id"] not in ledger}
        if new:
            write_ledger(ledger_path, {**ledger, **new})
        if not quiet:
            print(f"ledger: recorded {len(new)} new id(s) in {LEDGER}")

    emit(foods, out)

    if not quiet:
        c = counts(foods)
        print(f"OK  {c['total']} foods, 0 errors")
        print("    dietType: " + ", ".join(f"{d}={c[d]}" for d in DIET_TYPES))
        print(f"    minimums: total>={MINIMUMS['total']}, veg>={MINIMUMS['veg']}, "
              f"nonVeg>={MINIMUMS['nonVeg']}, every IFCT egg entry ({len(IFCT_EGG_CODES)})")
        pending = sum(1 for f in foods if f["reviewedBy"] == "pending-owner-review")
        noted = sum(1 for f in foods if f["_reviewNote"])
        no_page = sum(1 for f in foods if f["_ifctPage"] is None)
        print(f"    review: {pending} pending owner review, {noted} with a reviewNote, "
              f"{no_page} without an IFCT page number\n")
        print(f"NOT_IN_IFCT ({len(NOT_IN_IFCT)}) -- left out, for the owner's review:")
        for name, reason in NOT_IN_IFCT:
            print(f"  - {name}: {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
