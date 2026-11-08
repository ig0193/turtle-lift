"""Grain legumes -- IFCT 2017 group B. All veg.

IFCT tabulates dry pulses, so each row is the dry weight behind a cooked
household serving. One katori of cooked dal is taken as 30 g dry (owner
estimate); whole pulses that swell more are 35 g.
"""
from food_catalogue import food, OWNER_ESTIMATE as OE, VERIFIED

DAL = "1 katori cooked dal, 30 g dry"
SPROUT_YIELD = " Sprouted weight is about twice the dry weight; the yield is an owner estimate."

FOODS = [
    food("chana-dal", "Chana dal", ["bengal gram dal", "split chickpea"], "veg",
         "B001", 4, 21.55, DAL, 30, OE, VERIFIED),
    food("besan", "Besan", ["gram flour", "chickpea flour"], "veg",
         "B001", 4, 21.55, "1 besan chilla, 30 g besan", 30, OE,
         VERIFIED + " Besan is ground chana dal, which IFCT does not list; protein taken from "
         "Bengal gram dal (B001). Owner to confirm."),
    food("kala-chana", "Kala chana", ["bengal gram whole", "desi chana", "black chickpea"], "veg",
         "B002", 4, 18.77, "1 katori cooked kala chana, 35 g dry", 35, OE, VERIFIED),
    food("kala-chana-sprouts", "Kala chana sprouts", ["sprouted chana", "ankurit chana"], "veg",
         "B002", 4, 18.77, "1 katori sprouts, 35 g dry chana", 35, OE,
         VERIFIED + SPROUT_YIELD),
    food("urad-dal", "Urad dal", ["black gram dal", "dhuli urad", "uddina bele"], "veg",
         "B003", 4, 23.06, DAL, 30, OE, VERIFIED),
    food("sabut-urad", "Sabut urad", ["black gram whole", "kali dal", "maa ki dal"], "veg",
         "B004", 4, 21.97, DAL, 30, OE, VERIFIED),
    food("lobia", "Lobia", ["cowpea", "chawli", "black-eyed beans", "karamani"], "veg",
         "B005", 4, 20.36, "1 katori cooked lobia, 35 g dry", 35, OE, VERIFIED),
    food("safed-lobia", "Safed lobia", ["white cowpea", "white chawli"], "veg",
         "B006", 4, 21.25, "1 katori cooked lobia, 35 g dry", 35, OE, VERIFIED),
    food("moong-dal", "Moong dal", ["green gram dal", "dhuli moong", "yellow moong", "pesara pappu"], "veg",
         "B010", 4, 23.88, DAL, 30, OE, VERIFIED),
    food("moong-dal-chilla", "Moong dal chilla", ["moong chilla", "pesarattu"], "veg",
         "B010", 4, 23.88, "1 chilla, 30 g dry moong dal", 30, OE, VERIFIED),
    food("sabut-moong", "Sabut moong", ["green gram whole", "hari moong"], "veg",
         "B011", 4, 22.53, "1 katori cooked moong, 30 g dry", 30, OE, VERIFIED),
    food("moong-sprouts", "Moong sprouts", ["sprouted moong", "ankurit moong"], "veg",
         "B011", 4, 22.53, "1 katori sprouts, 35 g dry moong", 35, OE,
         VERIFIED + SPROUT_YIELD),
    food("kulthi", "Kulthi", ["horse gram", "hurali", "ulavalu", "kollu"], "veg",
         "B012", 4, 21.73, "1 katori cooked kulthi, 30 g dry", 30, OE,
         VERIFIED + " IFCT 2017 has one horse gram entry (whole)."),
    food("masoor-dal", "Masoor dal", ["red lentil", "lentil dal"], "veg",
         "B013", 4, 24.35, DAL, 30, OE, VERIFIED),
    food("sabut-masoor", "Sabut masoor", ["whole lentil", "brown lentil"], "veg",
         "B014", 5, 22.49, DAL, 30, OE, VERIFIED),
    food("matki", "Matki", ["moth beans", "math", "mat"], "veg",
         "B016", 5, 19.75, "1 katori cooked matki, 30 g dry", 30, OE, VERIFIED),
    food("dried-peas", "Dried peas", ["sukhe matar", "vatana", "safed matar"], "veg",
         "B017", 5, 20.43, "1 katori cooked ragda, 35 g dry", 35, OE, VERIFIED),
    food("chitra-rajma", "Chitra rajma", ["brown rajma", "speckled kidney beans"], "veg",
         "B019", 5, 19.5, "1 katori rajma curry, 35 g dry", 35, OE,
         VERIFIED + " IFCT entry is 'Rajmah, brown'."),
    food("rajma", "Rajma", ["red kidney beans"], "veg",
         "B020", 5, 19.91, "1 katori rajma curry, 35 g dry", 35, OE, VERIFIED),
    food("toor-dal", "Toor dal", ["arhar dal", "tuvar dal", "pigeon pea dal", "kandi pappu"], "veg",
         "B021", 5, 21.7, DAL, 30, OE, VERIFIED),
    food("sambar", "Sambar", ["sambhar"], "veg",
         "B021", 5, 21.7, "1 katori sambar, 20 g dry toor dal", 20, OE,
         VERIFIED + " Dal in sambar varies widely; 20 g dry per katori is an owner estimate."),
    food("sabut-toor", "Sabut toor", ["whole pigeon pea", "whole arhar"], "veg",
         "B022", 5, 20.47, "1 katori cooked toor, 30 g dry", 30, OE, VERIFIED),
    food("soya-bean", "Soya bean", ["soybean", "bhatmas"], "veg",
         "B024", 5, 35.58, "1 katori cooked soya bean, 30 g dry", 30, OE,
         VERIFIED + " IFCT lists brown (B024, 35.58 g) and white (B025, 37.8 g) soya bean; "
         "brown taken, the lower value."),
]
