local physical_profiles = require("@lib/physical_profiles")
-- Glass sheets. A pane goes into a grille, never straight onto the
-- deck: the grille is what holds it, which is why a window you can see
-- through still stops you walking through it.
return {
    id = "glass",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.glass.name",
    name = "glass sheets",
    sprite = "glass",
    inhand_sprite = { "held_glass_l", "held_glass_r" },
    -- tg glass.dm:35-36.
    pickup_sound = "glass_pickup",
    drop_sound = "glass_drop",
    stack = 50,
}
