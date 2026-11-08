"""Egg and egg products -- IFCT 2017 group M. All dietType egg.

A10 requires every IFCT egg entry (IFCT_EGG_CODES in food_catalogue.py) to be
carried by an egg row. IFCT 2017 Table 1 lists 15 egg entries, M001-M015,
all on book page 20; the codes and values below are read off that page.

Grams are the edible portion of one egg (owner estimate): hen egg 50 g,
country hen egg 40 g, duck egg 65 g, quail egg 10 g.
"""
from food_catalogue import food, OWNER_ESTIMATE as OE, VERIFIED

FOODS = [
    food("egg", "Egg", ["anda", "whole egg", "hen egg"], "egg",
         "M001", 20, 13.28, "1 egg, 50 g", 50, OE, VERIFIED),
    food("egg-white", "Egg white", ["anda safedi", "egg whites"], "egg",
         "M002", 20, 10.84, "1 egg white, 33 g", 33, OE, VERIFIED),
    food("egg-yolk", "Egg yolk", ["anda zardi"], "egg",
         "M003", 20, 15.74, "1 egg yolk, 17 g", 17, OE, VERIFIED),
    food("boiled-egg", "Boiled egg", ["ubla anda", "hard-boiled egg"], "egg",
         "M004", 20, 13.43, "1 boiled egg, 50 g", 50, OE, VERIFIED),
    food("boiled-egg-white", "Boiled egg white", ["ubla anda safedi", "boiled egg whites"], "egg",
         "M005", 20, 12.37, "1 boiled egg white, 33 g", 33, OE,
         VERIFIED + " Row added for A10: IFCT 2017 lists boiled white separately."),
    food("boiled-egg-yolk", "Boiled egg yolk", ["ubla anda zardi"], "egg",
         "M006", 20, 16.13, "1 boiled egg yolk, 17 g", 17, OE,
         VERIFIED + " Row added for A10: IFCT 2017 lists boiled yolk separately."),
    food("omelette", "Omelette", ["amlet"], "egg",
         "M007", 20, 16.53, "1-egg omelette, 50 g", 50, OE,
         VERIFIED + " Cooked weight of a 1-egg omelette is an owner estimate."),
    food("country-egg", "Country egg", ["desi anda", "nattu kozhi muttai"], "egg",
         "M008", 20, 13.14, "1 country egg, 40 g", 40, OE, VERIFIED),
    food("boiled-country-egg", "Boiled country egg", ["ubla desi anda"], "egg",
         "M009", 20, 14.43, "1 boiled country egg, 40 g", 40, OE, VERIFIED),
    food("country-egg-omelette", "Country egg omelette", ["desi anda amlet"], "egg",
         "M010", 20, 14.8, "1-egg omelette, 40 g", 40, OE, VERIFIED),
    food("boiled-duck-egg", "Boiled duck egg", ["ubla batakh ka anda"], "egg",
         "M011", 20, 13.8, "1 boiled duck egg, 65 g", 65, OE, VERIFIED),
    food("duck-egg", "Duck egg", ["batakh ka anda"], "egg",
         "M012", 20, 14.6, "1 duck egg, 65 g", 65, OE, VERIFIED),
    food("duck-egg-omelette", "Duck egg omelette", [], "egg",
         "M013", 20, 15.1, "1-egg omelette, 65 g", 65, OE, VERIFIED),
    food("quail-egg", "Quail egg", ["bater ka anda", "kaadai muttai"], "egg",
         "M014", 20, 12.39, "5 quail eggs, 50 g", 50, OE, VERIFIED),
    food("boiled-quail-egg", "Boiled quail egg", ["ubla bater ka anda"], "egg",
         "M015", 20, 13.03, "5 boiled quail eggs, 50 g", 50, OE,
         VERIFIED + " Row added for A10: IFCT 2017 lists boiled quail egg separately."),
]
