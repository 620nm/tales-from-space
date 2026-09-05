-- The air alarm, and the one thing about it that is not mechanism.
--
-- Everything a player DOES to one is native: the `link` module draws
-- the address, the state, the lock, the roster and the candidates, and
-- the `reach` module draws the settings of every machine joined to it
-- (docs/TGUI.md). There is deliberately no hook here that joins,
-- releases, unlocks or sets anything -- a second path to any of those
-- would be a second answer to who may.
--
-- What is left is a sentence, and it is `lib/network.luau`'s, said with
-- this box's nouns: a hub carries devices, and the devices an alarm
-- carries are the room's fans. The access point and the router are the
-- other two callers and differ in exactly those two words
-- (fixtures/access_point.luau, fixtures/network_router.luau).
--
-- IT IS NOT A RADIO RELAY, and that is the deliberate difference from
-- the other two boxes on this network. A tower, a wall box and a router
-- each do something to a `;` line crossing them (lib/radio_relay.luau);
-- an air alarm is a room's plumbing console and carries no speech, so
-- it registers neither stage and a line reaching it stops there.
--
-- It rides `interaction.use.done` rather than `interaction.use` for the
-- access point's reason: the decision anchor is where a handler
-- REPLACES the click, and replacing this one would eat both the panel
-- and the crowbar.
local content = {
    id = "air_alarm",
}

local NOUN = "air alarm"
local MEMBER = "machine"

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    script_definition:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        -- An empty hand, and a use that actually resolved: `implement`
        -- is absent for the crewman reading the box and present for the
        -- one taking it off the wall, and both arrive here.
        if ev.implement ~= nil or ev.outcome ~= "completed" then
            return
        end
        local said = network.line(ev.subject, NOUN, MEMBER)
        if said == nil then
            -- No address at all, which for a socketed box is one thing.
            said = sim.msg("lunatic/tfs:lib.network.no_card", {})
        end
        sim.message.send({ recipient = ev.actor, message = said })
    end)
end

return content
