local physical_profiles = require("@lib/physical_profiles")
local turbine_parts = require("@lib/power/turbine_parts")

-- tg's `/obj/item/turbine_parts/stator` (turbine_parts.dm:102-105): the stator
-- a turbine outlet is built around.
-- Every tier wears tg's one picture and says its rating on examine. tg
-- upgrades a part in place with sheets (turbine_parts.dm:56-90); here the
-- tool vendor sells tier one and tiers two to four are variants a map places.
return {
    id = "stator_part",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.stator_part.name",
    name = "stator part",
    sprite = "stator_part",
    category = "machine components",
    examine = turbine_parts.examine("stator", 1),
    component = turbine_parts.base("stator"),
    variants = {
        tier2 = {
            name_label = "lunatic/tfs:entity.stator_part.tier2.name",
            name = "stator part (tier 2)",
            examine = turbine_parts.examine("stator", 2),
            component = turbine_parts.rung("stator", 2),
        },
        tier3 = {
            name_label = "lunatic/tfs:entity.stator_part.tier3.name",
            name = "stator part (tier 3)",
            examine = turbine_parts.examine("stator", 3),
            component = turbine_parts.rung("stator", 3),
        },
        tier4 = {
            name_label = "lunatic/tfs:entity.stator_part.tier4.name",
            name = "stator part (tier 4)",
            examine = turbine_parts.examine("stator", 4),
            component = turbine_parts.rung("stator", 4),
        },
    },
}
