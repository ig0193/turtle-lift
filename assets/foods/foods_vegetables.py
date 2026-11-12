"""Vegetables: green leafy (IFCT 2017 group C), other vegetables (D), roots
and tubers (F), mushrooms (J). All veg.

Low in protein, but eaten daily, so they belong in a planned day.
"""
from food_catalogue import food, OWNER_ESTIMATE as OE, VERIFIED

FOODS = [
    food("drumstick-leaves", "Drumstick leaves", ["moringa leaves", "sahjan ke patte", "murungai keerai"], "veg",
         "C019", 6, 6.41, "1 katori leaves, 50 g", 50, OE, VERIFIED),
    food("methi-leaves", "Methi leaves", ["fenugreek leaves"], "veg",
         "C020", 6, 3.68, "1 katori leaves, 50 g", 50, OE, VERIFIED),
    food("spinach", "Spinach", ["palak"], "veg",
         "C033", 7, 2.14, "1 katori cooked palak, 100 g raw", 100, OE, VERIFIED),
    food("cauliflower", "Cauliflower", ["gobhi", "phool gobhi"], "veg",
         "D036", 9, 2.15, "1 katori sabzi, 100 g raw", 100, OE, VERIFIED),
    food("green-peas", "Green peas", ["matar", "hara matar"], "veg",
         "D061", 10, 7.25, "1 katori shelled peas, 80 g", 80, OE,
         VERIFIED + " IFCT entry is 'Peas, fresh'."),
    food("potato", "Potato", ["aloo", "batata"], "veg",
         "F006", 14, 1.54, "1 medium potato, 100 g", 100, OE,
         VERIFIED + " IFCT lists potato brown skin big (F006, 1.54 g), brown skin small "
         "(F007, 1.35 g) and red skin (F008, 1.83 g); the common brown-skinned potato taken."),
    food("button-mushroom", "Button mushroom", ["khumb", "mushroom"], "veg",
         "J001", 18, 3.68, "1 katori sliced, 100 g", 100, OE, VERIFIED),
]
