local physical_profiles = require("@lib/physical_profiles")
local turning = require("@lib/turning")
-- A floor drain, in your hands: set it on the deck and wrench it down.
local content = {
    id = "floor_drain_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.floor_drain_fitting.name",
    name = "floor drain fitting",
    hint_tags = { "pipe_part" },
    sprite = "floor_drain",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    -- The main it stands on, 1..=5, as every fitting's (air_scrubber_fitting).
    modes = 5,
    mode = 2,
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
