local physical_profiles = require("@lib/physical_profiles")
-- Lead-silicate glass sheets for radiation-shielded window panes.
return {
    id = "lead_glass",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.lead_glass.name",
    name = "lead glass sheets",
    sprite = "lead_glass",
    inhand_sprite = { "held_lead_glass_l", "held_lead_glass_r" },
    pickup_sound = "glass_pickup",
    drop_sound = "glass_drop",
    stack = 50,
    examine = {
        flavor = "Heavy amber lead-silicate glass sheets formulated for ionizing radiation shielding.",
    },
}
