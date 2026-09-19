local physical_profiles = require("@lib/physical_profiles")
-- The small round one, for the fittings that take it. Our ceilings are
-- all tubes so far, so a bulb is stock a janitor carries and cannot yet
-- fit anywhere — tg refuses it in a tube fixture too ("This type of
-- light requires a tube!", light.dm:396).
return {
    id = "light_bulb",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.light_bulb.name",
    name = "light bulb",
    sprite = "light_bulb",
}
