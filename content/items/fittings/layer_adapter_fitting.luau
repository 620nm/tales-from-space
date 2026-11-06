local physical_profiles = require("@lib/physical_profiles")
local turning = require("@lib/turning")
-- A layer adapter, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"manifoldlayer"` here (pipes/layermanifold.dm:13).
local content = {
    id = "layer_adapter_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.layer_adapter_fitting.name",
    name = "layer adapter fitting",
    hint_tags = { "pipe_part" },
    sprite = "layer_adapter_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    -- Alt+click turns it: tg gives every pipe item `simple_rotation`
    -- (code/game/machinery/pipe/construction.dm:169).
    gestures = turning.GESTURES,
    actions = turning.rows(),
}

if sim ~= nil then
    turning.attach(
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id }),
        { route = "self" }
    )
end

return content
