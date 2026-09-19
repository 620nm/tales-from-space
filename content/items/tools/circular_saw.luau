local physical_profiles = require("@lib/physical_profiles")
-- Cuts through bone (tg surgery_tools.dm:268-290): force 15, edged.
return {
    id = "circular_saw",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.circular_saw.name",
    name = "circular saw",
    sprite = "circular_saw",
    tool = "saw",
    tool_speed = 1,
    surgical = true,
    force = 15,
    sharp = "edged",
}
