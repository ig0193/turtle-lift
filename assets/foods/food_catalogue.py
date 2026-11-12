"""
food_catalogue.py -- shared constants and the row helper for the Diet food list.

Source of truth: IFCT 2017 -- Longvah T, Ananthan R, Bhaskarachary K,
Venkaiah K. *Indian Food Composition Tables 2017*. National Institute of
Nutrition, ICMR, Hyderabad. Protein is g per 100 g edible portion as IFCT
tabulates it (raw foods). A cooked dish is expressed through its main raw
ingredient, and the serving label names the cooked form, e.g.
"1 katori cooked dal, 30 g dry" (plan KTD10).

The source rows live one module per family (foods_*.py). validate_food_catalogue.py
checks them and emits foods.json (shipped) and foods.csv (owner review).
Never hand-edit the emitted files.

This is reviewed nutrition copy: a wrong number misleads a user about what
they eat. Every row stays `pending-owner-review` until the owner signs it off
(plan U19). `reviewNote` says what was checked and what is still a judgement;
it goes to foods.csv only, never to the app.

Codes and protein values were checked against Table 1 (Proximate Principles
and Dietary Fibre) of the NIN PDF, https://www.nin.res.in/ebooks/IFCT2017.pdf,
and cross-checked against the @ifct2017/compositions 2.0.9 data set, which
agrees on every code used here. Where IFCT gives mean +/- SD the mean is used.
`ifctPage` is the page number printed in the book (Table 1), which is the
PDF page minus 38.
"""

DIET_TYPES = ("veg", "egg", "nonVeg")

PENDING_REVIEW = "pending-owner-review"

# Where a household measure (and any cooked-to-dry yield) comes from, when no
# named portion-size reference was used.
OWNER_ESTIMATE = "owner estimate"

# reviewNote building block: the row's code and protein were read off IFCT
# 2017 Table 1. Anything after it in a note is a choice the owner should see.
VERIFIED = "Verified against IFCT 2017 Table 1 (NIN PDF): code and protein."

# A10: validator minimums.
MINIMUMS = {"total": 100, "veg": 60, "egg": 0, "nonVeg": 25}

# A10: every IFCT 2017 egg entry (group M) must be carried by an egg row.
# IFCT 2017 Table 1 lists 15: M001-M015 (book page 20).
IFCT_EGG_CODES = tuple(f"M{n:03d}" for n in range(1, 16))

# Foods users will look for that IFCT 2017 does not tabulate. R6: left out,
# never sourced elsewhere, printed by the validator and carried to the owner's
# review (U19). Never emitted.
NOT_IN_IFCT = (
    ("Whey protein", "supplement; not a food in IFCT 2017, and protein varies by brand"),
    ("Soya chunks (textured soy protein)", "defatted soy product; IFCT 2017 tabulates only whole soya bean"),
    ("Tofu", "not tabulated in IFCT 2017"),
    ("Greek yogurt / hung curd", "strained curd concentrates protein; not tabulated in IFCT 2017"),
    ("Cheese (processed, cheddar, mozzarella)", "not tabulated in IFCT 2017 milk group"),
    ("Ghee, butter, cream", "not protein foods; fats group only"),
    ("Kabuli chana (white chickpea)", "IFCT 2017 tabulates one whole Bengal gram (B002), not split by kabuli or desi; listed here as kala chana"),
    ("Sattu (roasted gram flour)", "roasted product not tabulated; raw Bengal gram is listed"),
    ("Roasted chana", "roasted product not tabulated; raw Bengal gram is listed"),
    ("Peanut butter", "branded product; raw groundnut is listed"),
    ("Oats", "not tabulated in IFCT 2017 cereals group"),
    ("Protein bars and branded high-protein products", "branded products; not in IFCT 2017"),
    ("Basa / pangasius fillet", "WRONG: IFCT 2017 does tabulate Pangas (S005, 17.12 g, book p.30); "
     "no row yet, owner to decide whether to add one and drop this entry"),
    ("Chia seeds", "not tabulated in IFCT 2017"),
    ("Pumpkin seeds", "not tabulated in IFCT 2017"),
    ("Mixed dishes (idli, dosa, khichdi, biryani)", "multi-ingredient recipes; IFCT 2017 tabulates raw foods only"),
)


def food(id, name, aliases, dietType, ifctCode, ifctPage, proteinPer100g,
         servingLabel, gramsPerServing, servingSource,
         reviewNote="", reviewedBy=PENDING_REVIEW):
    """One source row. `ifctPage` is None until the owner confirms it."""
    return {
        "id": id,
        "name": name,
        "aliases": list(aliases),
        "dietType": dietType,
        "ifctCode": ifctCode,
        "ifctPage": ifctPage,
        "proteinPer100g": proteinPer100g,
        "servingLabel": servingLabel,
        "gramsPerServing": gramsPerServing,
        "servingSource": servingSource,
        "reviewedBy": reviewedBy,
        "reviewNote": reviewNote,
    }
