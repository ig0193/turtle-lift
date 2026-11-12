"""Milk and milk products -- IFCT 2017 group L. All veg.

IFCT 2017 group L has four entries only: L001 buffalo milk, L002 cow milk,
L003 paneer, L004 khoa (book page 19).
"""
from food_catalogue import food, OWNER_ESTIMATE as OE, VERIFIED

FOODS = [
    food("cow-milk", "Cow milk", ["doodh", "gaay ka doodh", "whole milk"], "veg",
         "L002", 19, 3.26, "1 glass, 200 g", 200, OE, VERIFIED),
    food("buffalo-milk", "Buffalo milk", ["bhains ka doodh"], "veg",
         "L001", 19, 3.68, "1 glass, 200 g", 200, OE, VERIFIED),
    food("paneer", "Paneer", ["cottage cheese"], "veg",
         "L003", 19, 18.86, "5 cubes, 50 g", 50, OE, VERIFIED),
    food("khoa", "Khoa", ["khoya", "mawa"], "veg",
         "L004", 19, 16.34, "2 tbsp, 30 g", 30, OE, VERIFIED),
    food("curd", "Curd", ["dahi", "yogurt", "thayir"], "veg",
         "L002", 19, 3.26, "1 katori curd, 100 g", 100, OE,
         "Curd is not tabulated in IFCT 2017 (confirmed: group L has only L001-L004). "
         "Protein taken from whole cow milk (L002, 3.26 g, verified), the milk it is set from. "
         "Owner to confirm this equivalence or move curd to NOT_IN_IFCT."),
]
