local physical_profiles = require("@lib/physical_profiles")
-- Clamps a bleeder and lifts an organ out (tg surgery_tools.dm:32-49).
return {
    id = "hemostat",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.hemostat.name",
    name = "hemostat",
    sprite = "hemostat",
    tool = "hemostat",
    tool_speed = 1,
    surgical = true,
}
