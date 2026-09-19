local physical_profiles = require("@lib/physical_profiles")
local action_rules = require("@lib/action_rules")

-- A length of pipe, wrenched down under the deck on whichever of the
-- five piping layers you have it set to.
--
-- Like cable, this is not a structure transition: there is nothing
-- standing on the tile that owns the answer, so it stays an interaction.use
-- handler. Also like cable, it needs the subfloor OPEN -- pipe lives under
-- the plating, so you pry the tile up, run the line, and put the floor
-- back. The engine refuses a finished floor; this handler says so first,
-- because a refusal with no explanation reads as a bug.
--
-- THE LAYERS. tg has five, PIPING_LAYER_MIN..MAX with
-- PIPING_LAYER_DEFAULT = 3 (__DEFINES/atmospherics/atmos_piping.dm:78-80),
-- and two pipes on different layers do not connect
-- (atmosmachinery.dm:350). They are bare numbers in tg -- there are no
-- named piping layers and no per-layer colours -- so they are bare
-- numbers here. Layer 3 is the distribution run every dispenser hands
-- you; the others exist so a second run can CROSS the first without
-- joining it.

local content = {
    id = "pipe",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.pipe.name",
    name = "pipe",
    sprite = "pipe",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    stack = 25,
    -- Five settings, minted on the third: PIPING_LAYER_DEFAULT.
    modes = 5,
    mode = 2,
    -- tg cycles a pipe item's layer 1->2->3->4->5->1 on RIGHT-CLICK
    -- (construction.dm:438-445), because attack_self is already spoken
    -- for there (it rotates the fitting). We have no secondary-click
    -- channel, so the cycle moves to the in-hand key -- same cycle,
    -- same wrap, same balloon-alert-sized message.
}

content.actions = { action_rules.primary("lay_pipe", action_rules.exposed_deck("pipe")) }

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = assert(sim.mode(self))
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:lib.pipe.layer_set", {
                layer = next_index + 1,
            }),
        })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local _x, _y, _choice = x, y, choice
        -- Asked first, so every covered tile answers the same way and
        -- the reply is not a probe for what is already buried. Open
        -- deck, not "plating": the map decides per tile.
        local channel = "l" .. tostring(assert(sim.mode(self)).index + 1)
        if not sim.network_installable(x, y, "pipe", channel, "standard") then
            return { replaced = false }
        end
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.pipe.you_start_fitting_a_length", {}),
        })
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(1.0), {}) == "interrupted" then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:lib.pipe.fitting_stopped", {}),
                })
                return true
            end
            channel = "l" .. tostring(assert(sim.mode(self)).index + 1)
            if not sim.network_installable(x, y, "pipe", channel, "standard") then
                return true
            end
            sim.place_network(x, y, "pipe", channel, "standard", 15, nil, self, 1)
            sim.sound.play({ asset = "lunatic/tfs:sound/ratchet", at = ev.at })
        end)
        return true
    end)
end

return content
