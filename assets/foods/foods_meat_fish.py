"""Poultry (IFCT 2017 group N), animal meat (O), marine fish (P), marine
shellfish (Q), marine molluscs (R), freshwater fish and shellfish (S).
All dietType nonVeg.

Grams are raw edible portion (no bone, skin or shell), which is what IFCT
tabulates. "Mutton" in Indian usage is goat meat, so mutton rows cite goat.
Fish rows are one medium piece or a katori of cooked meat, 75 g raw edible
(owner estimate).

Where IFCT lists several species or cuts behind one everyday name, the note
names the alternatives; the choice leans to the commonest market form, and
otherwise to the lower value: over-stating protein misleads a user more than
under-stating it.
"""
from food_catalogue import food, OWNER_ESTIMATE as OE, VERIFIED

MEAT = "100 g raw, about 1 katori cooked"
FISH = "1 medium piece, 75 g raw"
SHELL = "1 katori cooked, 75 g raw shelled"

POULTRY = [
    food("chicken-breast", "Chicken breast", ["murgh breast", "boneless chicken"], "nonVeg",
         "N003", 20, 21.81, MEAT, 100, OE, VERIFIED + " IFCT entry is skinless broiler breast."),
    food("chicken-leg", "Chicken leg", ["chicken drumstick", "tangdi"], "nonVeg",
         "N001", 20, 19.44, "2 drumsticks, 100 g raw meat", 100, OE, VERIFIED),
    food("chicken-thigh", "Chicken thigh", [], "nonVeg",
         "N002", 20, 18.18, MEAT, 100, OE, VERIFIED),
    food("chicken-wing", "Chicken wing", [], "nonVeg",
         "N004", 20, 17.42, "2 wings, 60 g raw meat", 60, OE, VERIFIED),
    food("chicken-liver", "Chicken liver", ["kaleji"], "nonVeg",
         "N005", 21, 21.57, "1 katori cooked, 75 g raw", 75, OE, VERIFIED),
    food("chicken-gizzard", "Chicken gizzard", ["pota"], "nonVeg",
         "N006", 21, 18.22, "1 katori cooked, 75 g raw", 75, OE, VERIFIED),
    food("country-chicken", "Country chicken", ["desi murga", "nattu kozhi"], "nonVeg",
         "N007", 21, 17.01, MEAT, 100, OE,
         VERIFIED + " IFCT lists country hen only by cut, with skin: leg (N007, 17.01 g), thigh "
         "(N008, 18.29 g), breast (N009, 22.08 g), wing (N010, 18.65 g). Leg taken, the lowest, "
         "for a mixed curry cut. Owner to confirm."),
]

GOAT = [
    food("mutton-shoulder", "Mutton shoulder", ["goat meat", "bakre ka gosht", "mutton curry cut"], "nonVeg",
         "O001", 21, 20.33, MEAT, 100, OE, VERIFIED),
    food("mutton-chops", "Mutton chops", ["goat chops"], "nonVeg",
         "O002", 21, 20.39, "2 chops, 80 g raw meat", 80, OE, VERIFIED),
    food("mutton-leg", "Mutton leg", ["raan", "goat leg"], "nonVeg",
         "O003", 21, 22.07, MEAT, 100, OE, VERIFIED),
    food("mutton-keema", "Mutton keema", ["kheema", "minced mutton"], "nonVeg",
         "O001", 21, 20.33, "1 katori keema, 75 g raw", 75, OE,
         VERIFIED + " Keema is not in IFCT; taken as goat shoulder (O001). Owner to confirm."),
    food("mutton-brain", "Mutton brain", ["bheja", "goat brain"], "nonVeg",
         "O004", 21, 13.82, "1 katori cooked, 75 g raw", 75, OE, VERIFIED),
    food("mutton-liver", "Mutton liver", ["goat liver", "kaleji"], "nonVeg",
         "O008", 22, 20.32, "1 katori cooked, 75 g raw", 75, OE, VERIFIED),
    food("mutton-kidney", "Mutton kidney", ["gurda", "goat kidney"], "nonVeg",
         "O011", 22, 15.6, "1 katori cooked, 75 g raw", 75, OE, VERIFIED),
]

FISH_ROWS = [
    food("bombay-duck", "Bombay duck", ["bombil", "bombili"], "nonVeg",
         "P007", 25, 13.53, "2 pieces, 75 g raw", 75, OE, VERIFIED),
    food("hilsa", "Hilsa", ["ilish", "palla", "pulasa"], "nonVeg",
         "P017", 25, 21.8, FISH, 75, OE, VERIFIED),
    food("indian-mackerel", "Indian mackerel", ["bangda", "ayala", "bangude"], "nonVeg",
         "P034", 26, 21.51, "1 whole fish, 75 g raw edible", 75, OE,
         VERIFIED + " IFCT entry is 'Mackerel' (Rastrelliger kanagurta)."),
    food("indian-oil-sardine", "Indian oil sardine", ["mathi", "tarli", "chaala"], "nonVeg",
         "P071", 28, 17.91, "2 whole fish, 75 g raw edible", 75, OE,
         VERIFIED + " IFCT entry is 'Sardine' (Sardinella longiceps)."),
    food("indian-salmon", "Indian salmon", ["rawas", "threadfin"], "nonVeg",
         "P033", 26, 20.11, FISH, 75, OE,
         "Protein verified against IFCT 2017 Table 1 for P033. Equivalence, not an exact match: "
         "rawas (Eleutheronema tetradactylum) is not in IFCT; P033 'Maagaa' (Polynemus plebeius) is "
         "a threadfin of the same family. IFCT's 'Salmon' (P068) is Atlantic salmon, a different fish. "
         "Owner to confirm or move rawas to NOT_IN_IFCT."),
    food("black-pomfret", "Black pomfret", ["halwa fish", "karuppu vavval"], "nonVeg",
         "P055", 27, 18.91, FISH, 75, OE,
         VERIFIED + " IFCT also lists the same species as 'Aluva' (P002, 21.63 g); the named "
         "pomfret entry taken, the lower value."),
    food("white-pomfret", "White pomfret", ["paplet", "silver pomfret", "vavval"], "nonVeg",
         "P057", 27, 19.02, FISH, 75, OE, VERIFIED),
    food("seer-fish", "Seer fish", ["surmai", "vanjaram", "king mackerel"], "nonVeg",
         "P087", 28, 22.28, FISH, 75, OE,
         VERIFIED + " IFCT entry is 'Vanjaram' (Scomberomorus commerson)."),
    food("tuna", "Tuna", ["choora"], "nonVeg",
         "P084", 28, 24.5, FISH, 75, OE,
         VERIFIED + " IFCT 'Tuna' is Euthynnus affinis; it also lists striped tuna (P085, 21.28 g) "
         "and yellowfin as 'Kayrai' (P028, 20.15 g)."),
    food("prawns", "Prawns", ["jhinga", "kolambi", "shrimp", "chemmeen"], "nonVeg",
         "Q008", 29, 14.25, SHELL, 75, OE,
         VERIFIED + " IFCT lists marine tiger prawns orange (Q008, Penaeus monodon, 14.25 g) and "
         "brown (Q007, 14.85 g), and freshwater prawns big (S008, 19.24 g) and small (S009, 13.07 g). "
         "Q008 taken as the common market prawn. Owner to confirm."),
    food("crab", "Crab", ["kekda", "nandu", "kurlya"], "nonVeg",
         "Q005", 29, 10.0, "1 katori cooked, 75 g raw meat", 75, OE,
         VERIFIED + " IFCT lists crab (Q001, 10.23 g), sea crab (Q002, Portunus, 15.36 g), mud crab "
         "(Q005, Scylla, 10.0 g) and freshwater crab (S007, 13.23 g). Mud crab taken: common in "
         "India and the lowest value. Owner to confirm."),
    food("squid", "Squid", ["kanava", "calamari"], "nonVeg",
         "R006", 30, 16.25, SHELL, 75, OE,
         VERIFIED + " IFCT entry 'Squid, red' is Loligo duvaucelii, the main Indian squid; IFCT also "
         "lists black (R004, 16.1 g), hard shell/cuttlefish (R005, 16.82 g) and white small (R007, 17.41 g)."),
    food("mussels", "Mussels", ["kallumakkaya", "tisrya"], "nonVeg",
         "R001", 29, 12.14, "1 katori cooked, 75 g raw shelled", 75, OE,
         VERIFIED + " IFCT names R001 'Clam, green shell' but its species is Perna viridis, the "
         "green mussel (kallumakkaya). Note tisrya is usually a clam (IFCT R002, 11.82 g)."),
    food("rohu", "Rohu", ["rui", "rohu machh"], "nonVeg",
         "S006", 30, 19.71, FISH, 75, OE, VERIFIED),
    food("catla", "Catla", ["katla", "bhakur"], "nonVeg",
         "S002", 30, 17.94, FISH, 75, OE, VERIFIED),
    food("mrigal", "Mrigal", ["mirka", "naini"], "nonVeg",
         "S002", 30, 17.94, FISH, 75, OE,
         "NOT IN IFCT 2017: mrigal (Cirrhinus mrigala) has no entry. Equivalence: taken as catla "
         "(S002, 17.94 g, verified), a fellow Indian major carp and the lower of the two IFCT lists "
         "(rohu S006 is 19.71 g). Owner to keep this equivalence or retire the row."),
    food("tilapia", "Tilapia", [], "nonVeg",
         "P083", 28, 18.48, FISH, 75, OE,
         VERIFIED + " IFCT files tilapia under marine fish (P083)."),
]

FOODS = POULTRY + GOAT + FISH_ROWS
