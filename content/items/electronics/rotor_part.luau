local physical_profiles = require("@lib/physical_profiles")
local turbine_parts = require("@lib/power/turbine_parts")

-- tg's `/obj/item/turbine_parts/rotor` (turbine_parts.dm:97-100): the shaft a
-- core rotor is built around.
-- Every tier wears tg's one picture and says its rating on examine. tg
-- upgrades a part in place with sheets (turbine_parts.dm:56-90); here the
-- tool vendor sells tier one and tiers two to four are variants a map places.
return {
    id = "rotor_part",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.rotor_part.name",
    name = "rotor part",
    sprite = "rotor_part",
    category = "machine components",
    examine = turbine_parts.examine("rotor", 1),
    component = turbine_parts.base("rotor"),
    variants = {
        tier2 = {
            name_label = "lunatic/tfs:entity.rotor_part.tier2.name",
            name = "rotor part (tier 2)",
            examine = turbine_parts.examine("rotor", 2),
            component = turbine_parts.rung("rotor", 2),
        },
        tier3 = {
            name_label = "lunatic/tfs:entity.rotor_part.tier3.name",
            name = "rotor part (tier 3)",
            examine = turbine_parts.examine("rotor", 3),
            component = turbine_parts.rung("rotor", 3),
        },
        tier4 = {
            name_label = "lunatic/tfs:entity.rotor_part.tier4.name",
            name = "rotor part (tier 4)",
            examine = turbine_parts.examine("rotor", 4),
            component = turbine_parts.rung("rotor", 4),
        },
    },
}
