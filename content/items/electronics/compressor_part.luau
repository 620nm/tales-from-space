local physical_profiles = require("@lib/physical_profiles")
local turbine_parts = require("@lib/power/turbine_parts")

-- tg's `/obj/item/turbine_parts/compressor` (turbine_parts.dm:92-95): the blade
-- an inlet compressor is built around.
-- Every tier wears tg's one picture and says its rating on examine. tg
-- upgrades a part in place with sheets (turbine_parts.dm:56-90); here the
-- tool vendor sells tier one and tiers two to four are variants a map places.
return {
    id = "compressor_part",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.compressor_part.name",
    name = "compressor part",
    sprite = "compressor_part",
    category = "machine components",
    examine = turbine_parts.examine("compressor", 1),
    component = turbine_parts.base("compressor"),
    variants = {
        tier2 = {
            name_label = "lunatic/tfs:entity.compressor_part.tier2.name",
            name = "compressor part (tier 2)",
            examine = turbine_parts.examine("compressor", 2),
            component = turbine_parts.rung("compressor", 2),
        },
        tier3 = {
            name_label = "lunatic/tfs:entity.compressor_part.tier3.name",
            name = "compressor part (tier 3)",
            examine = turbine_parts.examine("compressor", 3),
            component = turbine_parts.rung("compressor", 3),
        },
        tier4 = {
            name_label = "lunatic/tfs:entity.compressor_part.tier4.name",
            name = "compressor part (tier 4)",
            examine = turbine_parts.examine("compressor", 4),
            component = turbine_parts.rung("compressor", 4),
        },
    },
}
