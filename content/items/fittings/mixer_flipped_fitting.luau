local physical_profiles = require("@lib/physical_profiles")
local turning = require("@lib/turning")
-- The mirrored mixer, as a fitting. tg's flipped mixer subtype
-- (mixer.dm:212-214) reached through the same flippable item.
--
-- Same picture, different machine: flipping moves which intake is
-- which, not what the thing looks like in a hand. See
-- items/filter_fitting.luau for why the pair are two items.
local content = {
    id = "mixer_flipped_fitting",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.mixer_flipped_fitting.name",
    name = "flipped mixer fitting",
    hint_tags = { "pipe_part" },
    sprite = "mixer_fitting",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    -- The main this one will stand on, 1..=5, and it is the ENGINE's
    -- dial rather than this file's: `modes` mints it, the dispenser
    -- sets it before it hands the part over (tg's `set_piping_layer`
    -- off the RPD, RPD.dm:569), and `attach_pipe_device` reads it when
    -- the machine stands up. Every `/obj/item/pipe` in tg carries one.
    -- Starting on the distribution run, tg's PIPING_LAYER_DEFAULT
    -- (__DEFINES/atmospherics/atmos_piping.dm:80).
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
