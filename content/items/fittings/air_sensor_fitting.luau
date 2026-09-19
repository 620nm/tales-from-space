local physical_profiles = require("@lib/physical_profiles")
return {
    id = "air_sensor_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.air_sensor_fitting.name",
    name = "air sensor fitting",
    sprite = "airlock_button",
    stack = 1,
    inhand_sprite = { "held_id_l", "held_id_r" },
}
