-- The network router's one sentence, which is the only thing about a
-- router that is not mechanism.
--
-- Everything a player DOES to one is native: the panel draws the
-- address, the derived state, the lock, the roster and the join
-- candidates, and a press on any of those rows goes through the same
-- helper a script's gesture would and leaves the same row on the record
-- (docs/TGUI.md, the `link` module). There is deliberately no hook here
-- that joins, releases or unlocks anything -- a second path to those
-- would be a second answer to who may -- and none that routes anything,
-- because who hears whom is the shape of the forest and nothing else
-- (docs/DEVICES.md §5).
--
-- What is left is a line of English. `sim.link_state` answers in the
-- engine's own closed vocabulary -- `online`, `unbound`, `suspended` --
-- so that a word read off a window is the word a reconstruction reads
-- off the log. None of those is a sentence anybody says out loud, and
-- turning them into one is a pack's job.
--
-- A SHUT PANEL SAYS NOTHING ABOUT THE NETWORK BEHIND IT, and neither
-- does this. What a lock protects is the ROSTER -- a list of what is
-- joined to somebody's rack is worth something to whoever is standing
-- at it -- so a locked router reports that it is locked and stops.
-- Printing the member count past a shut lock would be this pack walking
-- around the engine's own rule (docs/DEVICES.md §8).
--
-- It rides `interaction.use.done` rather than `interaction.use`: the
-- decision anchor is where a handler REPLACES the click, and replacing
-- this one would eat the panel that is the whole point of touching it.
local content = {
    id = "network_router",
}

local NOUN = "router"

-- One sentence about a node, or nil for a thing on no network -- which
-- for a socketed box means one thing, and the caller says so.
local function line(node)
    local state = sim.link_state(node)
    if state == nil then
        return nil
    end
    if state.locked then
        return "The " .. NOUN .. " is locked. Somebody with the right card could open it."
    end
    if state.suspended then
        return "The " .. NOUN .. " is not carrying anything. Check what is feeding it."
    end
    local held = state.members or 0
    if held == 0 then
        return "The " .. NOUN .. " is on the air with nothing joined to it."
    end
    if held == 1 then
        return "The " .. NOUN .. " is on the air, carrying one access point."
    end
    return "The " .. NOUN .. " is on the air, carrying " .. held .. " access points."
end

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    script_definition:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        -- An empty hand only. Something arriving at the rack in
        -- somebody's hand is a card, a screwdriver or a mistake, and
        -- each of those already has an answer.
        if ev.target ~= nil or ev.outcome ~= "completed" then
            return
        end
        local said = line(ev.subject)
        if said == nil then
            said = "There is no card in it. Until there is, it tops nothing."
        end
        sim.message.send({ recipient = ev.actor, message = said })
    end)
end

return content
