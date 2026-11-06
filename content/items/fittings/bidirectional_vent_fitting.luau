local physical_profiles = require("@lib/physical_profiles")
local turning = require("@lib/turning")
local content = {
    id = "bidirectional_vent_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.bidirectional_vent_fitting.name",
    name = "bidirectional vent fitting",
    hint_tags = { "pipe_part" },
    sprite = "bidirectional_vent_loose",
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
