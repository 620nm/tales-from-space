local physical_profiles = require("@lib/physical_profiles")
local action_rules = require("@lib/action_rules")

-- A multi-deck adapter: the one piece of pipe that joins the adapter
-- stacked directly above or below it, so two runs on different levels can
-- share gas (the engine's `docs/atmos/pipenets.md`).
--
-- tg's `/obj/machinery/atmospherics/pipe/multiz`
-- (pipes/multiz.dm:2-60), on the dispenser's Pipes shelf as
-- "Multi-Deck Adapter" (_globalvars/lists/pipe_recipes.dm:7). Laterally it
-- is pipe; vertically it joins an adapter on the SAME piping layer and no
-- other piece. Like heat-exchanging pipe it is laid from the hand on an
-- open deck, one per layer, and it takes no paint (`paintable = FALSE`,
-- multiz.dm:17). The wrench takes it back up like any length.
local content = {
    id = "pipe_adapter",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.pipe_adapter.name",
    name = "multi-deck adapter",
    hint_tags = { "pipe_part" },
    sprite = "pipe_adapter_loose",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    -- Five piping layers, minted on the third like every pipe off the shelf.
    modes = 5,
    mode = 2,
}

content.actions = { action_rules.primary("lay_pipe", action_rules.exposed_deck("pipe")) }
table.insert(content.actions, action_rules.self_use("set_layer"))

if sim ~= nil then
    -- The tile-address spelling of `sim.place_network`, named so the
    -- checker need not pick between its two overloads.
    local place_at: (TileAddress, string, string, string, number, string?, Handle?, number?) -> nil =
        sim.place_network
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = assert(sim.mode(self))
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:lib.pipe.layer_set", { layer = next_index + 1 }),
        })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, at = ev.subject, ev.actor, ev.at
        local channel = "l" .. tostring(assert(sim.mode(self)).index + 1)
        if not sim.network_installable(at, "pipe", channel, "adapter") then
            return { replaced = false }
        end
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.pipe_adapter.you_start_fitting_an_adapter", {}),
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
            if not sim.network_installable(at, "pipe", channel, "adapter") then
                return true
            end
            place_at(at, "pipe", channel, "adapter", 15, nil, self, 1)
            sim.sound.play({ asset = "lunatic/tfs:sound/ratchet", at = at })
        end)
        return true
    end)
end

return content
