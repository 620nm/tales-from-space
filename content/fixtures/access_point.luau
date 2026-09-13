-- The access point, and the one thing about it that is not mechanism.
--
-- Everything a player DOES to one of these is native and goes through a
-- held laptop's contact workspace: the address, the derived state, the
-- lock, the roster, the join candidates and the files are the target's
-- own modules (docs/LAPTOP.md, the engine's docs/pack-ui/server.md).
-- There is deliberately no hook here that joins, releases or unlocks
-- anything -- a second path to those would be a second answer to who may.
--
-- What is left is a sentence: a click that nothing took -- a bare hand,
-- a tool with no step here -- was refused by the `needs_laptop` row
-- (structures/access_point.luau), and the box says what it wants. A
-- crowbar's own step answers its click, so `resolved` keeps it quiet.
local content = {
    id = "access_point",
}

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:button_sequence", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:controller_request", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:device_outbox", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:device_sending", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:controller_status", { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:controller_timer", { replicate = "server" })
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("link.message.done", { kind = "react" }, controller.message)
    script_definition:handle("link.service.delivery", { kind = "react" }, controller.message)
    script_definition:handle("link.service.reply", { kind = "react" }, controller.message)
    -- Addressed completion is submitter delivered and therefore mod scoped;
    -- install it globally and let the controller verify the live slot.
    sim.handle("link.service.send.done", { kind = "react" }, controller.service_send_done)

    script_definition:handle("interaction.use.refused", { kind = "react", route = "interact" }, function(ev)
        local r = ev.action_refusal
        if r.action ~= "needs_laptop" or r.resolved then return end
        sim.message.send({
            recipient = ev.actor,
            message = sim.msg("lunatic/tfs:entity.access_point.needs_laptop", {}),
        })
    end)

    -- The two stages a hub stands on, the router's exactly
    -- (fixtures/network_router.luau): the key check for a tree this box
    -- happens to top, and the hop that changes nothing. A box under a
    -- router is never asked to read -- the top is -- and still holds
    -- the words on their way up (lib/radio_relay.luau).
    script_definition:handle("radio.read", { kind = "transform", route = "read" }, radio_relay.read)
    script_definition:handle("radio.carry", { kind = "transform", route = "carry" }, radio_relay.carry)
end

return content
