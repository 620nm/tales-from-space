local physical_profiles = require("@lib/physical_profiles")
-- Seals a wound with heat (tg surgery_tools.dm:65-83).
return {
    id = "cautery",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.cautery.name",
    name = "cautery",
    sprite = "cautery",
    tool = "cautery",
    tool_speed = 1,
    surgical = true,
}
