local physical_profiles = require("@lib/physical_profiles")
return {
    id = "bidirectional_vent_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.bidirectional_vent_fitting.name",
    name = "bidirectional vent fitting",
    sprite = "bidirectional_vent_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
