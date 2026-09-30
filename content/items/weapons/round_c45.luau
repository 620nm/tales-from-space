local physical_profiles = require("@lib/physical_profiles")

-- A live .45 round: tg's `/obj/item/ammo_casing/c45`
-- (code/modules/projectiles/ammunition/ballistic/smg.dm:21-25), the
-- C-20r's feed. It does nothing on its own; the magazine seats it and
-- the reload spends it into the weapon's charges.
return {
    id = "round_c45",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.round_c45.name",
    name = ".45 bullet casing",
    sprite = "live_casing",
    category = "weapons",
    examine = {
        flavor = "A .45 bullet casing, live primer up.",
    },
}
