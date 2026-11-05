local physical_profiles = require("@lib/physical_profiles")
-- Reinforced lead-silicate glass sheets with embedded rods for shielded windows.
return {
    id = "reinforced_lead_glass",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.reinforced_lead_glass.name",
    name = "reinforced lead glass sheets",
    sprite = "reinforced_lead_glass",
    inhand_sprite = { "held_reinforced_lead_glass_l", "held_reinforced_lead_glass_r" },
    pickup_sound = "glass_pickup",
    drop_sound = "glass_drop",
    stack = 50,
    examine = {
        flavor = "Heavy amber lead-silicate glass sheets with embedded reinforcing rods for high-integrity radiation shielding.",
    },
}
