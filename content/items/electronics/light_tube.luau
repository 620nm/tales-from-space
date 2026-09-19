local physical_profiles = require("@lib/physical_profiles")
-- A replacement tube. The whole of what a tube knows about itself is
-- that it is one: what happens when you push it into a fitting is the
-- FITTING's answer, in tfs/content/fixtures/light.luau
-- (docs/CONSTRUCTION.md — the target is the expert).
return {
    id = "light_tube",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.light_tube.name",
    name = "light tube",
    sprite = "light_tube",
}
