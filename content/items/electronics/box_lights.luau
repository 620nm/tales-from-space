local physical_profiles = require("@lib/physical_profiles")
-- tg's box of replacement lights: twenty-one fittings' worth, fourteen
-- tubes and seven bulbs (`/obj/item/storage/box/lights/mixed`,
-- service_boxes.dm:130-135, over `/datum/storage/box/lights` which
-- holds tubes and bulbs and nothing else).
--
-- Stocked the way the toolbox is: `holds` is spawned inside at
-- creation, one level deep.
return {
    id = "box_lights",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.box_lights.name",
    name = "box of replacement lights",
    sprite = "box_lights",
    storage = 21,
    holds = {
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_tube",
        "light_bulb",
        "light_bulb",
        "light_bulb",
        "light_bulb",
        "light_bulb",
        "light_bulb",
        "light_bulb",
    },
}
