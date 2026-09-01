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
        -- A use that actually resolved. `outcome` is the only thing
        -- this occurrence carries that can be asked a question: the
        -- click dispatcher raises `interaction.use` on the thing that
        -- was clicked with no held item on the record at all, so a
        -- crewman prying the box apart and a crewman touching it
        -- bare-handed arrive here indistinguishable, and the box
        -- narrates for both. That is a wart rather than a hazard --
        -- the line is true either way -- and gating it wants a fact
        -- the surface does not publish.
        if ev.outcome ~= "completed" then
            return
        end
        local said = network.line(ev.subject, NOUN, MEMBER)
        if said == nil then
            said = "There is no card in it. Until there is, it tops nothing."
        end
        sim.message.send({ recipient = ev.actor, message = said })
    end)
end

return content
