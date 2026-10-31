local physical_profiles = require("@lib/physical_profiles")
local firearm = require("@lib/firearm")

-- The C-20r's stick: tg's `/obj/item/ammo_box/magazine/smgm45`
-- (code/modules/projectiles/boxes_magazines/external/smg.dm:77-86), a
-- long .45 magazine holding 24. It ships loaded; loose rounds go in
-- through the hand, and only the right caliber seats — the row below
-- refuses anything else before the engine stows it.
local content = {
    id = "smg_mag",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.smg_mag.name",
    name = "SMG magazine (.45)",
    actions = { firearm.load_row("smg_mag") },
    sprite = "smg_mag",
    category = "weapons",
    storage = 24,
    holds = {
        "round_c45", "round_c45", "round_c45", "round_c45",
        "round_c45", "round_c45", "round_c45", "round_c45",
        "round_c45", "round_c45", "round_c45", "round_c45",
        "round_c45", "round_c45", "round_c45", "round_c45",
        "round_c45", "round_c45", "round_c45", "round_c45",
        "round_c45", "round_c45", "round_c45", "round_c45",
    },
    examine = {
        flavor = "A long .45 magazine, suitable for the C-20r SMG.",
    },
}

return content
