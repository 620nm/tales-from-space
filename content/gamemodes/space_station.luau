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
        preparation = {
            countdown_seconds = 120,
            fallback_job = "assistant",
        },
        -- Plain pack data. The native mode loader reads the mode rules,
        -- including preparation; `shift` remains pack policy read by this
        -- file and `lib/shift.luau`.
        shift = shift_rules,
        environment = {
            rolls = {
                { id = "cold_outdoors", required_tags = { "terrestrial" }, weight = 1 },
                { id = "dead_space", excluded_tags = { "terrestrial" }, weight = 4 },
                { id = "orbit", excluded_tags = { "terrestrial" }, weight = 3 },
                { id = "sunward", excluded_tags = { "terrestrial" }, weight = 1 },
                { id = "microgravity", excluded_tags = { "terrestrial" }, weight = 1 },
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

    behavior:handle("round.allocate", { kind = "transform", route = "lifecycle" }, preparation.allocate)

    behavior:handle("clock.second", { kind = "react" }, function(ev)
        shift.on_second(shift_rules, ev)
    end)

    behavior:handle("round.end", { kind = "react" }, function()
        shift.on_end(shift_rules)
    end)
end

return content
