local physical_profiles = require("@lib/physical_profiles")
return {
    id = "airlock_button_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.airlock_button_fitting.name",
    name = "button fitting",
    sprite = "airlock_button",
    stack = 1,
    inhand_sprite = { "held_id_l", "held_id_r" },
}
