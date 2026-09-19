local physical_profiles = require("@lib/physical_profiles")
-- Stitches an incision shut (tg stacks/medical.dm:582).
return {
    id = "suture",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.suture.name",
    name = "suture",
    sprite = "suture",
    tool = "suture",
    tool_speed = 1,
    surgical = true,
}
