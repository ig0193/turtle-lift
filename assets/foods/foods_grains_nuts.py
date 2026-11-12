"""Cereals and millets (IFCT 2017 group A), nuts and oil seeds (group H). All veg.

Breads and cooked grains are expressed through their dry flour or grain; the
label names the cooked form. Fat added in cooking adds no protein.
"""
from food_catalogue import food, OWNER_ESTIMATE as OE, VERIFIED

RICE = "1 katori cooked rice, 50 g raw"

GRAINS = [
    food("rajgira", "Rajgira", ["amaranth seed", "ramdana"], "veg",
         "A002", 3, 13.27, "1 katori rajgira, 30 g", 30, OE,
         VERIFIED + " IFCT lists black (A001, 14.59 g) and pale brown (A002, 13.27 g) amaranth "
         "seed; pale brown taken, as the rajgira sold in India is the pale seed."),
    food("bajra", "Bajra", ["pearl millet", "sajje", "kambu"], "veg",
         "A003", 3, 10.96, "1 bajra roti, 40 g flour", 40, OE, VERIFIED),
    food("barley", "Barley", ["jau"], "veg",
         "A004", 3, 10.94, "1 katori cooked barley, 30 g dry", 30, OE, VERIFIED),
    food("jowar", "Jowar", ["sorghum", "jonna", "cholam"], "veg",
         "A005", 3, 9.97, "1 jowar bhakri, 40 g flour", 40, OE, VERIFIED),
    food("makki-atta", "Makki atta", ["maize flour", "corn flour"], "veg",
         "A006", 3, 8.8, "1 makki roti, 40 g flour", 40, OE,
         VERIFIED + " IFCT tabulates dry maize grain (A006), not the flour; the flour is the ground grain."),
    food("sweet-corn", "Sweet corn", ["bhutta", "corn kernels"], "veg",
         "A008", 3, 4.16, "1 katori kernels, 80 g", 80, OE,
         VERIFIED + " IFCT entry is 'Maize, tender, sweet'."),
    food("quinoa", "Quinoa", [], "veg",
         "A009", 3, 13.11, "1 katori cooked quinoa, 40 g dry", 40, OE, VERIFIED),
    food("ragi", "Ragi", ["finger millet", "nachni", "mandua"], "veg",
         "A010", 3, 7.16, "1 ragi roti, 40 g flour", 40, OE, VERIFIED),
    food("poha", "Poha", ["rice flakes", "aval", "chivda"], "veg",
         "A011", 3, 7.44, "1 plate poha, 50 g dry flakes", 50, OE, VERIFIED),
    food("murmura", "Murmura", ["puffed rice", "mamra", "pori"], "veg",
         "A012", 3, 7.47, "1 katori murmura, 15 g", 15, OE, VERIFIED),
    food("brown-rice", "Brown rice", [], "veg",
         "A013", 3, 9.16, RICE, 50, OE, VERIFIED),
    food("parboiled-rice", "Parboiled rice", ["ukda chawal", "sela rice", "boiled rice"], "veg",
         "A014", 3, 7.81, RICE, 50, OE, VERIFIED),
    food("rice", "Rice", ["chawal", "white rice"], "veg",
         "A015", 3, 7.94, RICE, 50, OE, VERIFIED),
    food("maida", "Maida", ["refined flour"], "veg",
         "A018", 3, 10.36, "1 naan, 60 g maida", 60, OE, VERIFIED),
    food("roti", "Roti", ["chapati", "phulka", "atta"], "veg",
         "A019", 4, 10.57, "1 roti, 30 g atta", 30, OE, VERIFIED),
    food("paratha", "Paratha", ["plain paratha"], "veg",
         "A019", 4, 10.57, "1 plain paratha, 45 g atta", 45, OE, VERIFIED),
    food("dalia", "Dalia", ["broken wheat", "lapsi"], "veg",
         "A020", 4, 10.59, "1 katori cooked dalia, 30 g dry", 30, OE,
         VERIFIED + " Dalia is cracked whole wheat, which IFCT does not list; protein taken from "
         "wheat, whole (A020). IFCT's bulgur (A021, 10.84 g) is parboiled cracked wheat. Owner to confirm."),
    food("suji", "Suji", ["rava", "semolina", "upma"], "veg",
         "A022", 4, 11.38, "1 plate upma, 50 g dry rava", 50, OE, VERIFIED),
    food("seviyan", "Seviyan", ["vermicelli", "semiya"], "veg",
         "A023", 4, 9.7, "1 katori cooked seviyan, 30 g dry", 30, OE,
         VERIFIED + " IFCT also lists roasted vermicelli (A024, 10.37 g); plain taken."),
]

NUTS = [
    food("almonds", "Almonds", ["badam"], "veg",
         "H001", 17, 18.41, "10 almonds, 12 g", 12, OE, VERIFIED),
    food("cashews", "Cashews", ["kaju"], "veg",
         "H005", 17, 18.78, "10 cashews, 15 g", 15, OE, VERIFIED),
    food("garden-cress-seeds", "Garden cress seeds", ["halim", "aliv"], "veg",
         "H008", 17, 23.36, "1 tsp, 5 g", 5, OE, VERIFIED),
    food("sesame-seeds", "Sesame seeds", ["til", "gingelly", "ellu"], "veg",
         "H011", 17, 21.7, "1 tbsp, 9 g", 9, OE,
         VERIFIED + " IFCT lists gingelly seeds black (H009, 19.17 g), brown (H010, 21.61 g) and "
         "white (H011, 21.7 g); white taken as the common til."),
    food("peanuts", "Peanuts", ["groundnut", "moongphali", "shengdana", "kadalai"], "veg",
         "H012", 17, 23.65, "1 handful, 30 g", 30, OE, VERIFIED),
    food("flaxseed", "Flaxseed", ["alsi", "linseed"], "veg",
         "H014", 17, 18.55, "1 tbsp, 10 g", 10, OE, VERIFIED),
    food("pistachios", "Pistachios", ["pista"], "veg",
         "H018", 18, 23.35, "1 handful, 20 g", 20, OE, VERIFIED),
    food("sunflower-seeds", "Sunflower seeds", [], "veg",
         "H020", 18, 23.53, "1 tbsp, 10 g", 10, OE, VERIFIED),
    food("walnuts", "Walnuts", ["akhrot"], "veg",
         "H021", 18, 14.92, "5 walnut halves, 15 g", 15, OE, VERIFIED),
]

FOODS = GRAINS + NUTS
