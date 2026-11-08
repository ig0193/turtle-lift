#!/usr/bin/env python3
"""
test_validate_food_catalogue.py -- failure cases for validate_food_catalogue.py,
run against a tiny fixture, plus the real tables end to end.

    cd assets/foods && python3 -m unittest -q test_validate_food_catalogue

CI runs this in the generated-data job before the validator itself.
"""
import hashlib
import tempfile
import unittest
from pathlib import Path

import validate_food_catalogue as v
from food_catalogue import food

NO_MINIMUMS = {"total": 0, "veg": 0, "egg": 0, "nonVeg": 0}


def row(id="toor-dal", name="Toor dal", diet="veg", p100=21.7, grams=30, **kw):
    """One valid fixture row; override a field to break it."""
    r = food(id, name, ["arhar dal"], diet, "B022", None, p100,
             "1 katori cooked dal, 30 g dry", grams, "owner estimate")
    r.update(kw)
    return r


def run(rows, ledger=None, minimums=NO_MINIMUMS, egg_codes=()):
    errors, _ = v.validate(rows, ledger or {}, minimums=minimums, egg_codes=egg_codes)
    return errors


def mentions(errors, *needles):
    return any(all(n in e for n in needles) for e in errors)


class FixtureFailures(unittest.TestCase):
    def test_valid_fixture_passes_and_computes_protein_per_serving(self):
        errors, foods = v.validate([row()], {}, minimums=NO_MINIMUMS, egg_codes=())
        self.assertEqual(errors, [])
        self.assertEqual(foods[0]["proteinPerServingG"], 6.5)  # 21.7 * 30 / 100 = 6.51

    def test_protein_per_serving_above_grams_fails_naming_id(self):
        # Only reachable with p100 > 100, so both checks fire; the per-serving
        # one must still name the id.
        errors = run([row(id="bad-food", p100=150, grams=10)])
        self.assertTrue(mentions(errors, "bad-food", "protein per serving"), errors)

    def test_ledger_id_missing_from_rows_fails_with_removed_id(self):
        errors = run([row()], ledger={"toor-dal": "veg", "moong-dal": "veg"})
        self.assertTrue(mentions(errors, "removed id", "moong-dal"), errors)

    def test_ledger_diet_type_change_fails(self):
        errors = run([row()], ledger={"toor-dal": "egg"})
        self.assertTrue(mentions(errors, "toor-dal", "dietType"), errors)

    def test_id_not_in_ledger_fails_without_update_flag(self):
        # A real run must flag an id the ledger has never recorded.
        errors, _ = v.validate([row()], {}, minimums=NO_MINIMUMS, egg_codes=(),
                               require_ledger=True)
        self.assertTrue(mentions(errors, "toor-dal", "--update-ledger"), errors)

    def test_unknown_diet_type_fails(self):
        errors = run([row(diet="vegan")])
        self.assertTrue(mentions(errors, "toor-dal", "vegan"), errors)

    def test_duplicate_id_fails(self):
        errors = run([row(), row(name="Arhar dal")])
        self.assertTrue(mentions(errors, "duplicate id", "toor-dal"), errors)

    def test_names_differing_only_in_case_fail(self):
        errors = run([row(), row(id="toor-dal-2", name="TOOR DAL")])
        self.assertTrue(mentions(errors, "duplicate name"), errors)

    def test_id_not_lower_case_hyphen_fails(self):
        for bad in ("Toor-dal", "toor_dal", "toor dal", "-toor", "toor--dal", "toor-"):
            with self.subTest(bad=bad):
                self.assertTrue(mentions(run([row(id=bad)]), bad, "id"), bad)

    def test_protein_per_100g_out_of_range_fails(self):
        for bad in (0, -1, 100.1):
            with self.subTest(bad=bad):
                self.assertTrue(mentions(run([row(p100=bad)]), "proteinPer100g"), bad)

    def test_protein_per_100g_of_exactly_100_is_allowed(self):
        self.assertFalse(mentions(run([row(p100=100, grams=10)]), "proteinPer100g"))

    def test_grams_per_serving_must_be_positive_integer(self):
        for bad in (0, -5, 12.5, "30"):
            with self.subTest(bad=bad):
                self.assertTrue(mentions(run([row(grams=bad)]), "gramsPerServing"), bad)

    def test_empty_ifct_code_fails(self):
        self.assertTrue(mentions(run([row(ifctCode="  ")]), "ifctCode"))

    def test_empty_serving_source_fails(self):
        self.assertTrue(mentions(run([row(servingSource="")]), "servingSource"))

    def test_missing_field_fails(self):
        r = row()
        del r["servingLabel"]
        self.assertTrue(mentions(run([r]), "missing field", "servingLabel"))

    def test_empty_reviewed_by_fails_but_pending_is_allowed(self):
        self.assertTrue(mentions(run([row(reviewedBy="")]), "reviewedBy"))
        self.assertEqual(run([row(reviewedBy="pending-owner-review")]), [])

    def test_aliases_must_be_a_list_of_non_empty_strings(self):
        self.assertTrue(mentions(run([row(aliases="dahi")]), "aliases"))
        self.assertTrue(mentions(run([row(aliases=[""])]), "aliases"))

    def test_counts_under_minimums_fail(self):
        errors = run([row()], minimums=v.MINIMUMS)
        for needle in ("total", "veg", "nonVeg"):
            self.assertTrue(mentions(errors, needle), (needle, errors))

    def test_missing_ifct_egg_entry_fails(self):
        egg = row(id="egg", name="Egg", diet="egg", ifctCode="M001")
        errors = run([egg], egg_codes=("M001", "M002"))
        self.assertTrue(mentions(errors, "M002"), errors)
        self.assertFalse(mentions(errors, "M001"), errors)

    def test_egg_code_on_non_egg_row_does_not_count(self):
        errors = run([row(ifctCode="M001")], egg_codes=("M001",))
        self.assertTrue(mentions(errors, "M001"), errors)

    def test_output_is_sorted_by_id(self):
        _, foods = v.validate([row(id="zz", name="Zz"), row(id="aa", name="Aa")], {},
                              minimums=NO_MINIMUMS, egg_codes=())
        self.assertEqual([f["id"] for f in foods], ["aa", "zz"])

    def test_review_note_and_source_fields_stay_out_of_json(self):
        _, foods = v.validate([row(reviewNote="check value")], {},
                              minimums=NO_MINIMUMS, egg_codes=())
        self.assertEqual(list(foods[0]), list(v.JSON_FIELDS))


class RealTables(unittest.TestCase):
    def emit_twice(self):
        digests = []
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            for out in (a, b):
                self.assertEqual(v.main(["--out", out, "--quiet"]), 0)
                digests.append({n: hashlib.sha256(Path(out, n).read_bytes()).hexdigest()
                                for n in ("foods.json", "foods.csv")})
        return digests

    def test_real_tables_pass_and_meet_minimums(self):
        errors, foods = v.validate(v.load_rows(), v.read_ledger(v.HERE / v.LEDGER),
                                   require_ledger=True)
        self.assertEqual(errors, [])
        counts = v.counts(foods)
        self.assertGreaterEqual(counts["total"], 100)
        self.assertGreaterEqual(counts["veg"], 60)
        self.assertGreaterEqual(counts["nonVeg"], 25)

    def test_second_run_is_byte_identical(self):
        first, second = self.emit_twice()
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
