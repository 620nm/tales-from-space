-- The network router's one sentence, which is the access point's one
-- sentence with a different noun in it (fixtures/access_point.luau
-- explains why this is all there is, and lib/network.luau is where the
-- sentence itself lives).
--
-- Everything a player DOES to a router is native panel work, and who
-- hears whom is the shape of the forest and nothing else -- neither of
-- those is a hook's business (docs/DEVICES.md §5, §9).
--
-- A ROOT CARRIES HUBS. That is the whole of what this file knows that
-- the access point's does not: a router accepts access points and never
-- devices, so the word its line counts in is the access point's name
-- rather than the general one.
local content = {
    id = "network_router",
}

local NOUN = "router"
local MEMBER = "access point"

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    script_definition:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        -- AN EMPTY HAND, and a use that actually resolved.
        -- `implement` is what the actor was holding and is absent for
        -- an empty hand, which is the whole difference between a
        -- crewman reading the rack and a crewman opening its panel with
        -- a screwdriver -- both arrive here, because the tool's own
        -- step completes this one on its way past.
        if ev.implement ~= nil or ev.outcome ~= "completed" then
            return
        end
        local said = network.line(ev.subject, NOUN, MEMBER)
        if said == nil then
            said = sim.msg("lunatic/tfs:fixtures.network_router.no_card", {})
        end
        sim.message.send({ recipient = ev.actor, message = said })
    end)

    -- The two stages a top stands on. `radio.read` is the tree's key
    -- check -- the router is asked which tower reads a line no tower
    -- could make out, and it names the first one keyed to the word --
    -- and `radio.carry` is the hop that changes nothing, registered so
    -- that the words pass through this rack at all
    -- (lib/radio_relay.luau, docs/luau-api/radio-relay.md).
    script_definition:handle("radio.read", { kind = "transform", route = "read" }, radio_relay.read)
    script_definition:handle("radio.carry", { kind = "transform", route = "carry" }, radio_relay.carry)
end

return content
