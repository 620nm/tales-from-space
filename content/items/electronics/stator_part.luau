local physical_profiles = require("@lib/physical_profiles")
local turbine_parts = require("@lib/turbine_parts")

-- tg's `/obj/item/turbine_parts/stator` (turbine_parts.dm:102-105): the stator
-- a turbine outlet is built around.
-- Every tier wears tg's one picture. tg upgrades a part in place with
-- sheets (turbine_parts.dm:56-90); here a rung is a variant a map or a
-- crate supplies, as for the stock parts.
return {
    id = "stator_part",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.stator_part.name",
    name = "stator part",
    sprite = "stator_part",
    category = "machine components",
    examine = { flavor = "Install in a turbine engine turbine to increase its performance." },
    component = turbine_parts.base("stator"),
    variants = {
        tier2 = {
            name_label = "lunatic/tfs:entity.stator_part.tier2.name",
            name = "stator part (tier 2)",
            component = turbine_parts.rung("stator", 2),
        },
        tier3 = {
            name_label = "lunatic/tfs:entity.stator_part.tier3.name",
            name = "stator part (tier 3)",
            component = turbine_parts.rung("stator", 3),
        },
        tier4 = {
            name_label = "lunatic/tfs:entity.stator_part.tier4.name",
            name = "stator part (tier 4)",
            component = turbine_parts.rung("stator", 4),
        },
    },
}
