local physical_profiles = require("@lib/physical_profiles")
local turbine_parts = require("@lib/turbine_parts")

-- tg's `/obj/item/turbine_parts/compressor` (turbine_parts.dm:92-95): the blade
-- an inlet compressor is built around.
-- Every tier wears tg's one picture. tg upgrades a part in place with
-- sheets (turbine_parts.dm:56-90); here a rung is a variant a map or a
-- crate supplies, as for the stock parts.
return {
    id = "compressor_part",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.compressor_part.name",
    name = "compressor part",
    sprite = "compressor_part",
    category = "machine components",
    examine = { flavor = "Install in a turbine engine compressor to increase its performance." },
    component = turbine_parts.base("compressor"),
    variants = {
        tier2 = {
            name_label = "lunatic/tfs:entity.compressor_part.tier2.name",
            name = "compressor part (tier 2)",
            component = turbine_parts.rung("compressor", 2),
        },
        tier3 = {
            name_label = "lunatic/tfs:entity.compressor_part.tier3.name",
            name = "compressor part (tier 3)",
            component = turbine_parts.rung("compressor", 3),
        },
        tier4 = {
            name_label = "lunatic/tfs:entity.compressor_part.tier4.name",
            name = "compressor part (tier 4)",
            component = turbine_parts.rung("compressor", 4),
        },
    },
}
