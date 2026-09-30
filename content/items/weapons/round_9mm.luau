local physical_profiles = require("@lib/physical_profiles")

-- A live 9mm round: tg's `/obj/item/ammo_casing/c9mm`
-- (code/modules/projectiles/ammunition/ballistic/pistol.dm:27-31).
-- No magazine on the station feeds it yet, so it is the wrong caliber
-- everywhere — the round the compat gate turns away.
return {
    id = "round_9mm",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.round_9mm.name",
    name = "9mm bullet casing",
    sprite = "live_casing",
    category = "weapons",
    examine = {
        flavor = "A 9mm bullet casing, live primer up.",
    },
}
