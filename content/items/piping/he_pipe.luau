local physical_profiles = require("@lib/physical_profiles")
local action_rules = require("@lib/action_rules")

-- A length of heat-exchanging pipe: the run you lay when you WANT the
-- room to feel what is inside it.
--
-- tg's `/obj/machinery/atmospherics/pipe/heat_exchanging/simple`
-- (heat_exchange/simple.dm, he_pipes.dm). Ordinary pipe is a sealed
-- tube that trades nothing with the deck it is buried under. This is the
-- opposite piece of kit: thin-walled, matte grey, and every pass it
-- conducts with the air of the tile above it, once the two differ by
-- more than the deadband. Both numbers live in `lib/thermal.luau`,
-- which says where each came from and what moving it does. The
-- deadband is why a run already at the room's temperature does nothing
-- at all, and why a freezer loop laid through a hot room bleeds it dry.
--
-- IT JOINS ONLY ITSELF (tg's `HE_type_check`, he_pipes.dm:18-21). A
-- heat-exchange run and a distribution main can touch end to end on one
-- layer and stay two networks, which is what the junction is for
-- (structures/he_junction.luau).
--
-- IT TAKES NO PAINT. tg fixes the colour at `#404040` outright
-- (`add_atom_colour(..., FIXED_COLOUR_PRIORITY)`, he_pipes.dm:15), and a
-- thing with a colour of its own has no second colour to be -- the same
-- rule the colour adapter keeps. The painter says so.
--
-- THREE LAYERS, not five: tg's sheets carry piping layers 2, 3 and 4 and
-- no others (`he-simple.dmi`), so those are the ones this fits.
local LAYERS = { 2, 3, 4 }

local content = {
    id = "he_pipe",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.he_pipe.name",
    name = "heat-exchanging pipe",
    sprite = "he_pipe",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    stack = 25,
    -- The engine's dial is the piping layer, 1..5, and this fits three
    -- of them; the cycle below walks those three. Minted on layer 3,
    -- PIPING_LAYER_DEFAULT, like everything else off the shelf.
    modes = 5,
    mode = 2,
}

content.actions = { action_rules.primary("lay_pipe", action_rules.exposed_deck("pipe")) }

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local layer = assert(sim.mode(self)).index + 1
        -- 2 -> 3 -> 4 -> 2. Ordinary pipe wraps 1..5; this wraps the
        -- three tg drew art for, so the dial never stops somewhere the
        -- wrench would refuse.
        local next_layer = LAYERS[1]
        for i, candidate in ipairs(LAYERS) do
            if candidate == layer then
                next_layer = LAYERS[(i % #LAYERS) + 1]
                break
            end
        end
        sim.set_mode(self, next_layer - 1)
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:lib.pipe.layer_set", { layer = next_layer }),
        })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local _x, _y, _choice = x, y, choice
        local channel = "l" .. tostring(assert(sim.mode(self)).index + 1)
        if not sim.network_installable(x, y, "pipe", channel, "he_pipe") then
            return { replaced = false }
        end
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.he_pipe.you_start_fitting_a_length", {}),
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
            if not sim.network_installable(x, y, "pipe", channel, "he_pipe") then
                return true
            end
            sim.place_network(x, y, "pipe", channel, "he_pipe", 15, nil, self, 1)
            sim.sound.play({ asset = "lunatic/tfs:sound/ratchet", at = ev.at })
        end)
        return true
    end)
end

return content
