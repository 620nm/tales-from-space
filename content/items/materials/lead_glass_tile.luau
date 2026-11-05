local physical_profiles = require("@lib/physical_profiles")
-- What prying up a lead glass floor returns; stack size and scatter follow
-- floor_tile.luau, and held art shares `glass_tile`'s.
return {
    id = "lead_glass_tile",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.lead_glass_tile.name",
    name = "lead glass floor tiles",
    sprite = "lead_glass_tile",
    inhand_sprite = { "held_glass_tile_l", "held_glass_tile_r" },
    stack = 60,
    scatter = 3,
    examine = {
        flavor = "Amber lead-silicate glass floor tiles pried up from a shielded deck window.",
    },
}
