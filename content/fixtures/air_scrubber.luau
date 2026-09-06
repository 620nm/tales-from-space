-- The air scrubber, and the one thing about it that is not mechanism.
--
-- It is the vent's argument exactly (fixtures/vent.luau): the engine
-- sorts this machine's own tile into one of three words on the atmos
-- cadence and raises the anchor only when the word changes
-- (docs/atmos/hazard-sensing.md), and all this file does is repeat it
-- onto the network. Both machines say the same sentence, so the
-- sentence is written once in `lib/netmsg.luau` and named twice.
--
-- The pair is the whole roster the engine samples -- a scrubber and a
-- vent are what a room HAS in it, where an injector is plant somebody
-- plumbed for a purpose and a meter is a gauge on a pipe.
local content = {
    id = "air_scrubber",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- No `route`, for the vent's reason (fixtures/vent.luau).
    script_definition:handle("atmos.hazard.done", { kind = "react" }, netmsg.report_hazard)
end

return content
