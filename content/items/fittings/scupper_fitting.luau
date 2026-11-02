local physical_profiles = require("@lib/physical_profiles")
-- A scupper, in your hands: hold it and hang it on the wall beside you.
return {
    id = "scupper_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.scupper_fitting.name",
    name = "scupper fitting",
    hint_tags = { "pipe_part" },
    sprite = "scupper",
    category = "fittings",
    stack = 1,
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
