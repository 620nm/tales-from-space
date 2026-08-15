-- A meter, in your hands rather than on a run.
--
-- tg's `/obj/item/pipe_meter` (code/game/machinery/pipe/
-- construction.dm:460-470), and it is the same round trip every
-- atmospherics device is placed by: you put the fitting on the tile,
-- wrench it, and the machine stands up in its place
-- (`/obj/item/pipe_meter/wrench_act`, construction.dm:472-486).
-- Unfastening the meter mints this back onto the deck, and so does the
-- run under it going away.
--
-- No hooks, no tool class, no stack: this file is a NOUN. What a wrench
-- does to it is the meter's business, and it is written down in
-- structures/meter.luau where the target is the expert.
return {
    id = "pipe_meter",
    name = "meter",
    -- tg's `icon_state = "meter"` off the fittings sheet: the gauge
    -- with no pipe drawn through it, because in your hands it is
    -- attached to nothing.
    sprite = "pipe_meter",
    -- `inhand_icon_state = "buildpipe"` (construction.dm:465) -- one
    -- length of pipe over the shoulder, like every other fitting.
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
