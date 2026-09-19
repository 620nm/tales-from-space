local physical_profiles = require("@lib/physical_profiles")
local action_rules = require("@lib/action_rules")

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
--
-- The in-hand key turns the same dial one layer at a time, 1-2-3-4-5-1:
-- tg's `/obj/item/pipe/attack_hand_secondary` cycle
-- (construction.dm:438-445), which its own `/obj/item/pipe_meter`
-- never inherits, moved to the key since there is no secondary-click
-- channel. Same wrap, same balloon-alert-sized message, and the row
-- sits on the held meter's own card.
local CHANNELS = { "l1", "l2", "l3", "l4", "l5" }

local content = {
    id = "pipe_meter",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.pipe_meter.name",
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
}

content.actions = {
    action_rules.primary("set_layer", action_rules.network("pipe")),
    {
        id = "cycle_layer",
        gesture = "self",
        route = "self_use",
        label = "lunatic/tfs:ui.affordance.set_layer",
    },
}

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local target = ev.claim
        local _x, _y, _choice = x, y, choice
        if target == nil or target.kind ~= "network" then
            return { replaced = false }
        end
        local network = sim.network(x, y, target.instance)
        if network == nil or network.network ~= "pipe" then
            return { replaced = false }
        end
        for index, channel in ipairs(CHANNELS) do
            if network.channel == channel then
                sim.set_mode(self, index - 1)
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.pipe_meter.layer", { layer = index }),
                })
                return true
            end
        end
        return { replaced = false }
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = assert(sim.mode(self))
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.pipe_meter.layer", { layer = next_index + 1 }),
        })
        return true
    end)
end

return content
