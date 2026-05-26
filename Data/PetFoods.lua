-- Pet food item database: itemID → diet type (matches GetPetFoodTypes() strings).
--
-- Item IDs sourced from FeedOMatic by Gazmik Fizzwidget (original author).
-- TBC Classic support maintained by Beast-Masters-addons.
--   Original: https://github.com/fizzwidget/feed-o-matic
--   TBC fork:  https://github.com/Beast-Masters-addons/feed-o-matic
-- No explicit license was found in either repository. Item IDs are game data
-- facts (not copyrightable expression); full attribution is given here in
-- recognition of the research effort that went into compiling this list.
--
-- Scope: Vanilla + TBC era items only. Post-TBC items are absent because they
-- cannot appear in TBC Classic Anniversary player bags.
-- INEDIBLE items (cooking ingredients / raw catches the pet may reject) are
-- intentionally excluded; only BASIC, BONUS, and CONJURED items are included.

local PetFoods = {}
Quiver.Data = Quiver.Data or {}
Quiver.Data.PetFoods = PetFoods

local lookup = {}

local function add(diet, ids)
    for _, id in ipairs(ids) do
        lookup[id] = diet
    end
end

-- ── Meat ─────────────────────────────────────────────────────────────────────

add("Meat", {
    -- raw / vendor
    117, 2287, 2679, 2681, 2685, 3770, 3771, 4599, 5478, 6890, 7097, 8952,
    9681, 11444, 17119, 17407, 19223, 19224, 19304, 19305, 19306, 19995,
    21235, 23495,
    -- TBC raw
    27854, 29451, 30610, 32685, 32686, 33254, 33454, 34747, 35953,
    -- cooked (Well Fed buff)
    1017, 2680, 2684, 2687, 2888, 3220, 3662, 3726, 3727, 3728, 3729, 4457,
    5472, 5474, 5477, 5479, 5480, 12209, 12210, 12213, 12224, 13851, 17222,
    18045, 20074, 21023, 24105,
    -- TBC cooked
    27635, 27636, 27651, 27655, 27657, 27658, 27659, 27660, 29292, 31672,
    31673, 33872, 34125, 34410, 34748, 34749, 34750, 34751, 34752, 34754,
    34755, 34756, 34757, 34758, 35563, 35565,
    -- raw cooking ingredients (valid uncooked pet food)
    723, 729, 769, 1015, 1080, 1081, 2672, 2673, 2677, 2886, 2924, 3173,
    3404, 3667, 3712, 3730, 3731, 4739, 5051, 5465, 5467, 5469, 5470, 5471,
    12037, 12184, 12202, 12203, 12204, 12205, 12208, 12223, 20424, 21024,
    22644, 23676,
    -- TBC raw ingredients
    27668, 27669, 27671, 27674, 27677, 27678, 27681, 27682, 31670, 31671,
    33120, 34736, 35562, 35794,
})

-- ── Fish ─────────────────────────────────────────────────────────────────────

add("Fish", {
    -- raw / vendor
    787, 1326, 2682, 4592, 4593, 4594, 5095, 6290, 6316, 6887, 8364, 8957,
    8959, 12238, 13546, 13930, 13933, 13935, 16766, 19996, 21071, 21153, 21552,
    -- TBC raw
    27661, 27858, 29452, 33004, 33048, 33053, 33451, 34759, 34760, 34761,
    35285, 35951,
    -- cooked (Well Fed buff)
    5476, 5525, 5527, 6038, 12216, 13927, 13928, 13929, 13932, 13934, 16971,
    21072, 21217,
    -- TBC cooked
    27662, 27663, 27664, 27665, 27666, 27667, 30155, 33052, 33867, 34762,
    34763, 34764, 34765, 34766, 34767, 34768, 34769,
    -- raw fishing catches (valid uncooked pet food)
    -- NOTE: 6889 (Small Egg) excluded — bird egg, not fish; rejected by pets in TBC Classic
    2674, 2675, 4603, 4655, 5468, 5503, 5504, 6289, 6291, 6303, 6308, 6317,
    6361, 6362, 7974, 8365, 12206, 12207, 13754, 13755, 13756, 13758,
    13759, 13760, 13888, 13889, 13890, 13893, 15924, 24477,
    -- TBC raw catches
    27422, 27425, 27429, 27435, 27437, 27438, 27439, 27515, 27516, 33823,
    33824,
})

-- ── Bread ─────────────────────────────────────────────────────────────────────

add("Bread", {
    -- conjured mage food
    34062, 8076,
    -- vendor / basic
    4540, 4541, 4542, 4544, 4601, 8950, 13724, 16169, 19301, 19696, 20857,
    23160, 24072,
    -- TBC vendor / basic
    27855, 28486, 29394, 29449, 30816, 33449, 34780, 35950,
    -- cooked (Well Fed buff)
    2683, 3666, 17197,
})

-- ── Cheese ───────────────────────────────────────────────────────────────────

add("Cheese", {
    414, 422, 1707, 2070, 3927, 8932, 17406,
    -- TBC
    27857, 29448, 30458, 33443, 35952,
    -- cooked
    3665, 12218,
})

-- ── Fruit ────────────────────────────────────────────────────────────────────

add("Fruit", {
    4536, 4537, 4538, 4539, 4602, 8953, 16168, 19994, 20031, 21030, 21031,
    21033, 22324,
    -- TBC
    27856, 28112, 29393, 29450, 35948, 35949,
    -- cooked (Well Fed buff)
    11950, 13810, 20516, 24009,
    -- TBC cooked
    32721,
})

-- ── Fungus ───────────────────────────────────────────────────────────────────

add("Fungus", {
    3448, 4604, 4605, 4606, 4607, 4608, 8948,
    -- TBC
    27859, 29453, 30355, 33452, 35947,
    -- cooked (Well Fed buff)
    24539, 24008,
    -- raw ingredient
    27676,
})

-- ── Pet-buff treats (TBC) ─────────────────────────────────────────────────────
-- These items are right-clicked directly from the bag — no Feed Pet needed.
-- They buff the pet's stats and should always appear first in the food picker,
-- regardless of the pet's diet type.

local petBuffIDs = {
    [33874] = true,  -- Kibler's Bits: +20 Str/Stamina to pet for 1 hour
    [27656] = true,  -- Sporeling Snack: +20 Stamina/Spirit to pet for 30 min
}

-- ── Public API ────────────────────────────────────────────────────────────────

PetFoods.lookup    = lookup
PetFoods.petBuffIDs = petBuffIDs

-- Returns true if itemID is valid pet food matching the given diet set.
-- petFoodTypes: { [dietName] = true } from GetPetFoodTypes(), or nil to skip diet check.
function PetFoods:IsPetFood(itemID, petFoodTypes)
    local diet = lookup[itemID]
    if not diet then return false end
    if not petFoodTypes then return true end
    return petFoodTypes[diet] == true
end
