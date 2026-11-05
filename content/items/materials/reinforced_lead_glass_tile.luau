local physical_profiles = require("@lib/physical_profiles")
-- What prying up a reinforced lead glass floor returns; stack size, scatter,
-- and held art follow reinforced_glass_tile.luau.
return {
    id = "reinforced_lead_glass_tile",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.reinforced_lead_glass_tile.name",
    name = "reinforced lead glass floor tiles",
    sprite = "reinforced_lead_glass_tile",
    inhand_sprite = { "held_reinforced_glass_tile_l", "held_reinforced_glass_tile_r" },
    stack = 60,
    scatter = 3,
    examine = {
        flavor = "Wire-reinforced amber lead-silicate glass floor tiles pried up from a shielded deck window.",
    },
}
