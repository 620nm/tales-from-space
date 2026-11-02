local physical_profiles = require("@lib/physical_profiles")
-- A sump pump, in your hands: set it on the deck and wrench it down.
return {
    id = "sump_pump_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.sump_pump_fitting.name",
    name = "sump pump fitting",
    hint_tags = { "pipe_part" },
    sprite = "sump_pump_off_n",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    -- The main it stands on, 1..=5, as every fitting's (air_scrubber_fitting).
    modes = 5,
    mode = 2,
}
