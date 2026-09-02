-- Development construction playground: a connection owns one disposable
-- body and supplies never run out.
--
-- The shift is the same hour the station gets. A sandbox whose map never
-- refreshed would be a sandbox nobody could reset, and a mode whose
-- rules were an exception to the pack's would be a second answer to when
-- a round ends (`content/lib/shift.luau`).
local shift_rules = {
    shift_minutes = 60,
    grace_seconds = 30,
    -- Seconds of shift REMAINING at each warning.
    warnings = { 600, 300, 60 },
    announcer = "Charter Command",
    channel = "Common",
}

local content = {
    id = "free_build",
    name = "Free Build",
    -- A map posted for a playtest boots into this one: a mapper wants
    -- to walk the station they just drew with the tools to poke at it,
    -- not to queue at a job board for a shift they are not playing.
    playtest = true,
    rules = {
        bodies = "connection",
        respawn = "uncontrollable",
        -- What every crew body spawned under this mode wears
        -- (docs/BIOLOGY.md §1). A job may name its own instead;
        -- without either there would be nothing to spawn.
        body = "human",
        infinite_vending = true,
        shift = shift_rules,
        -- Nobody picks a job here, so the sandbox body is issued the
        -- Station Engineer's standard kit — jumpsuit, ID, stocked
        -- toolbelt, metal and tiles. It is the gear, not the job: no
        -- slot is taken and the crew manifest is unchanged. Somebody
        -- who spawns to build should already be holding the tools.
        outfit = "engineer",
        -- One sky and no dice: a sandbox that came out sunward some
        -- days and not others would make every temperature reading in
        -- it a question about the weather.
        environment = {
            sink_k = 2.7,
            rolls = {
                { id = "dead_space", name = "dead space", weight = 1, insolation = 0 },
            },
        },
    },
}

-- The mode loader reads this file in a bare VM with no `sim` and no
-- shared library (`gamemodes/space_station.luau` says the same).
if sim ~= nil then
    shift.validate(content.id, shift_rules)

    local behavior = sim.define("behavior", "lunatic/tfs:free_build_shift", {
        prototype = content.id,
    })

    behavior:handle("clock.second", { kind = "react" }, function(ev)
        shift.on_second(shift_rules, ev)
    end)

    behavior:handle("round.end", { kind = "react" }, function()
        shift.on_end(shift_rules)
    end)
end

return content
