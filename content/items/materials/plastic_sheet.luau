local physical_profiles = require("@lib/physical_profiles")
-- A stack of plain polymer sheets. The packager makes these from the same
-- resin feedstock as pellets; construction recipes may name this material
-- directly without teaching the chemistry machine another product format.
return {
    id = "plastic_sheet",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.plastic_sheet.name",
    name = "plastic sheets",
    sprite = "plasteel",
    inhand_sprite = { "held_plasteel_l", "held_plasteel_r" },
    pickup_sound = "metal_pickup",
    drop_sound = "metal_drop",
    stack = 1,
}
