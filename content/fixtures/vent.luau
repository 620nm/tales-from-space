-- The air vent, and the one thing about it that is not mechanism.
--
-- Everything a fan DOES is native: which way it blows, the dead band
-- it holds a room to, the pressures it reads, the picture it wears
-- (docs/atmos/room-devices.md). Even the judgement about the air is
-- the engine's -- it sorts this fan's own tile into one of three words
-- once an atmos pass, against the bands `content/tuning.luau` sets,
-- and raises the anchor only on a crossing
-- (docs/atmos/hazard-sensing.md).
--
-- What is left is one sentence said to nobody in particular: the fan
-- repeats the word onto its own network and stops. It does not decide
-- what the word means, does not know whether anything heard it, and
-- does not care whether it is joined to an air alarm or still hanging
-- off the panel that feeds it -- the roster and the meaning are the
-- alarm's (fixtures/air_alarm.luau), and the body of this handler is
-- `lib/netmsg.luau`'s because the scrubber says exactly the same
-- thing.
--
-- IT REPORTS UNJOINED TOO, and that is the engine's decision rather
-- than this file's: a reading keyed to network membership would change
-- meaning the moment somebody pulled a card.
local content = {
    id = "vent",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- NO `route`. A completion the engine queues re-enters on its own
    -- route, and a handler that names one is only offered occurrences
    -- that arrived by it -- which for this anchor is none at all
    -- (crates/lunatic-server/src/script/mod.rs, the handler filter).
    script_definition:handle("atmos.hazard.done", { kind = "react" }, netmsg.report_hazard)
end

return content
