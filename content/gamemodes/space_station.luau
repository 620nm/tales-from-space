-- The full station round: persistent characters, finite supplies, and an
-- hour on the clock. A crewman the pack calls dead may leave the body
-- behind and return to the job board as somebody new; the corpse stays
-- where it fell for whoever finds it.
--
-- The shift itself is `content/lib/shift.luau` -- which second a warning
-- goes out on, when the round is asked to end. This file declares the
-- numbers and binds the two handlers to the mode.
local shift_rules = {
    shift_minutes = 60,
    -- How long the world keeps ticking after `round.end` publishes, so
    -- the closing line lands before the map is replaced.
    grace_seconds = 30,
    -- Seconds of shift REMAINING at each warning.
    warnings = { 600, 300, 60 },
    announcer = "Charter Command",
    channel = "Common",
}

local content = {
    id = "space_station",
    name = "Space Station",
    default = true,
    rules = {
        bodies = "persistent",
        respawn = "inanimate",
        body = "human",
        infinite_vending = false,
        -- Plain pack data. The native mode loader checks only that
        -- lifecycle modes carry bounded data; this file and
        -- `lib/shift.luau` are its sole interpreters.
        shift = shift_rules,
        environment = {
            sink_k = 2.7,
            rolls = {
                { id = "dead_space", name = "dead space", weight = 4, insolation = 0 },
                { id = "orbit", name = "orbit", weight = 3, insolation = 1361 },
                { id = "sunward", name = "close solar orbit", weight = 1, insolation = 2700 },
            },
        },
    },
}

-- The mode loader reads this file in a bare VM with no `sim` and no
-- shared library, so both the check and the handlers live behind the
-- guard. Under the script host the check runs at definition time, which
-- makes a bad number a `--load-only` failure rather than a shift that
-- quietly never ends.
if sim ~= nil then
    shift.validate(content.id, shift_rules)

    local behavior = sim.define("behavior", "lunatic/tfs:space_station_shift", {
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
