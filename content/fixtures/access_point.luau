-- The access point, and the one thing about it that is not mechanism.
--
-- Everything a player DOES to one of these is native: the panel draws
-- the address, the derived state, the lock, the roster and the join
-- candidates, and a press on any of those rows goes through the same
-- helper a script's gesture would and leaves the same row on the record
-- (docs/TGUI.md, the `link` module). There is deliberately no hook here
-- that joins, releases or unlocks anything -- a second path to those
-- would be a second answer to who may.
--
-- What is left is a sentence. A crewman who walks up and touches the
-- box gets its window AND one line in this pack's own words, because
-- `online` and `suspended` are the engine's vocabulary and nobody says
-- them out loud. The line comes off `lib/network.luau`, which the
-- router reads too -- a hub carries devices where a root carries hubs,
-- and that difference is the only thing the two callers disagree about.
--
-- It rides `interaction.use.done` rather than `interaction.use`: the
-- decision anchor is where a handler REPLACES the click, and replacing
-- this one would eat both the panel and the crowbar, which are the two
-- things touching the box is actually for.
local content = {
    id = "access_point",
}

local NOUN = "access point"
local MEMBER = "device"

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    script_definition:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        -- AN EMPTY HAND, and a use that actually resolved.
        -- `implement` is what the actor was holding and is absent for
        -- an empty hand, which is the whole difference between a
        -- crewman reading the box and a crewman taking it off the wall
        -- -- both arrive here, because the crowbar's own step completes
        -- this one on its way past.
        if ev.implement ~= nil or ev.outcome ~= "completed" then
            return
        end
        local said = network.line(ev.subject, NOUN, MEMBER)
        if said == nil then
            -- No address at all, which for a socketed box is one thing:
            -- there is nothing in the socket to lend it one.
            said = "There is no card in it. Until there is, it is on no network."
        end
        sim.message.send({ recipient = ev.actor, message = said })
    end)
end

return content
