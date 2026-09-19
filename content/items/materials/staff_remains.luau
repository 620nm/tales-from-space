local physical_profiles = require("@lib/physical_profiles")
-- A pack-declared matter-bearing remain for staff disassembly. The engine
-- only sees an item prototype and mints it through the normal item path.
return {
    id = "staff_remains",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.staff_remains.name",
    name = "remains",
    sprite = "bottle",
    volume_ml = 50,
    contents = { water = 0.125 },
}
