-- The station's names, in one place: the `given_names` and `family_names`
-- rosters (`rosters/*.luau`, which the engine reads) and the cadaver stock
-- (`lib/cadaver_stock.luau`) both draw on these lists.

local crew_names = {}

crew_names.given = {
    "Urist", "Joan", "Pavel", "Sasha", "Miriam", "Ezekiel", "Nadia", "Cormac", "Beatrix", "Dmitri",
    "Harlan", "Ingrid", "Kofi", "Lupe", "Mortimer", "Priya",
} :: { string }

crew_names.family = {
    "McHands",
    "Voss",
    "Okafor",
    "Delacroix",
    "Hardt",
    "Ives",
    "Katsaros",
    "Lindqvist",
    "Moroz",
    "Nakamura",
    "Osei",
    "Pike",
    "Quintana",
    "Reyes",
    "Sokolov",
    "Thistlewood",
} :: { string }

return crew_names
