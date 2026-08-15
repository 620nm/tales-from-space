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
-- A loose meter starts on PIPING_LAYER_DEFAULT. Using it on one exact,
-- exposed pipe changes that per-instance layer to the pipe clicked --
-- tg's `/obj/machinery/atmospherics/pipe/item_interaction`, which sets
-- the item's `piping_layer` before dropping it (pipes.dm:92-99).
-- Lunatic has no scripted drop-item effect, so the ordinary drop key is
-- one extra input before wrenching; the layer selection itself remains
-- exact and server-validated.
local LAYERS = { 1, 2, 4, 8, 16 }

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
    modes = 5,
    mode = 2,
    on_use = function(ctx, self, user, _x, _y, _choice, target)
        if target == nil or target.kind ~= "pipe" then
            return "pass"
        end
        for index, layer in ipairs(LAYERS) do
            if target.layer == layer then
                ctx.set_mode(self, index - 1)
                ctx.system_msg(user, "Meter layer set to " .. index .. ". Drop it before fastening.")
                return
            end
        end
        return "pass"
    end,
}
