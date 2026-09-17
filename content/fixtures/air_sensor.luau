local netmsg = require("@lib/netmsg")

-- The air sensor, and the one thing about it that is not mechanism.
--
-- Everything a sensor DOES is native: the engine sorts the air on its
-- own tile into one of three words once an atmos pass, against the
-- bands `content/tuning.luau` sets, and raises the anchor only on a
-- crossing (the engine's docs/atmos/hazard-sensing.md). Directional
-- sensors read beside the fixtures through the same edge and the same
-- occurrence -- the worst of their own tile and every side their mask
-- keeps -- so a sensor beside a fire reports it like a vent would.
--
-- What is left is one sentence said to nobody in particular: the
-- sensor repeats the word onto its own network and stops. It does not
-- decide what the word means, does not know whether anything heard it,
-- and does not care whether it is joined to an access point or still
-- hanging off nothing -- the roster and the meaning are the alarm's
-- (fixtures/air_alarm.luau), and the body of this handler is
-- `lib/netmsg.luau`'s because the vent says exactly the same thing.
--
-- IT REPORTS UNJOINED TOO, and that is the engine's decision rather
-- than this file's: a reading keyed to network membership would change
-- meaning the moment somebody pulled a card.
local content = {
    id = "air_sensor",
}

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- NO `route`. A completion the engine queues re-enters on its own
    -- route, and a handler that names one is only offered occurrences
    -- that arrived by it -- which for this anchor is none at all
    -- (the engine's script dispatch, the handler filter).
    script_definition:handle("atmos.hazard.done", { kind = "react" }, netmsg.report_hazard)
end

return content
