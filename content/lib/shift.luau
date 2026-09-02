-- WHEN A SHIFT ENDS, in one place.
--
-- The engine knows no round length. It publishes `clock.second` once a
-- second of sim time -- through the finalization grace as well -- and
-- replaces the world only after content has said `sim.round.finish`.
-- The hour is this pack's opinion, and it is the same opinion under
-- every mode, so it lives here rather than once per `gamemodes/` file.
--
-- A mode declares the numbers in `rules.shift` and binds the two
-- handlers to `clock.second` and `round.end`. Everything else -- what
-- counts as a legal declaration, which second a warning goes out on,
-- and which sentence it is -- is below.
--
-- NOTHING HERE MAY RAISE. A handler that throws is disabled for the
-- rest of the shift, so one runtime error before the last second would
-- be a round that never ends. The arithmetic is over numbers
-- `validate` already accepted, and no call below reads round-scoped
-- state -- which stops being legal the moment `round.end` returns.

local shift = {}

-- Everyone still watching the station, ghosts included
-- (content/audiences.luau).
local AUDIENCE = "lunatic/tfs:round"

local WARNING = "lunatic/tfs:shift_warning"
local FINAL_MINUTE = "lunatic/tfs:shift_final_minute"
local OVER = "lunatic/tfs:shift_over"

local MINUTE = 60
local MAX_MINUTES = 1440
-- The engine's own ceiling on a round-end grace, refused here rather
-- than clamped there: a mode that asked for more would be shortened
-- without being told (`crates/lunatic-server/src/script/effect.rs`,
-- `MAX_ROUND_END_GRACE_SECS`).
local MAX_GRACE = 120

local function fail(mode, detail)
    error("gamemodes/" .. mode .. " rules.shift: " .. detail)
end

local function whole(value, low, high)
    return type(value) == "number" and value % 1 == 0 and value >= low and value <= high
end

local function nonempty(value)
    return type(value) == "string" and #value > 0
end

-- Checked where the mode file declares it, so a typo is a `--load-only`
-- failure rather than a shift that quietly never ends.
function shift.validate(mode, rules)
    if type(rules) ~= "table" then
        fail(mode, "must be a table")
    end
    if not whole(rules.shift_minutes, 1, MAX_MINUTES) then
        fail(mode, "shift_minutes must be a whole number of minutes from 1 to " .. MAX_MINUTES)
    end
    if not whole(rules.grace_seconds, 0, MAX_GRACE) then
        fail(mode, "grace_seconds must be a whole number of seconds from 0 to " .. MAX_GRACE)
    end
    if type(rules.warnings) ~= "table" then
        fail(mode, "warnings must be a list of seconds-remaining marks")
    end
    -- `on_second` walks the marks with `ipairs`, which stops at the
    -- first hole and never sees a named key. Counting `pairs` against
    -- the length is what makes a mark that would silently never fire a
    -- load failure instead.
    local entries = 0
    for _ in pairs(rules.warnings) do
        entries += 1
    end
    if entries ~= #rules.warnings then
        fail(mode, "warnings must be a dense list, with no gaps and no named keys")
    end
    local total = rules.shift_minutes * MINUTE
    local seen = {}
    for _, mark in ipairs(rules.warnings) do
        -- A mark is a whole minute of REMAINING time, so the crew hears
        -- a round number and the sentence needs no fractions.
        if not whole(mark, MINUTE, total - MINUTE) or mark % MINUTE ~= 0 then
            fail(mode, "each warning must be a whole minute of remaining time inside the shift")
        end
        if seen[mark] then
            fail(mode, "warnings must not repeat a mark")
        end
        seen[mark] = true
    end
    if not nonempty(rules.announcer) then
        fail(mode, "announcer must be a non-empty name")
    end
    if not nonempty(rules.channel) then
        fail(mode, "channel must be a non-empty name")
    end
end

function shift.announce(rules, message)
    sim.message.notify({
        audience = AUDIENCE,
        sender = rules.announcer,
        channel = rules.channel,
        message = message,
    })
end

-- One second of sim time. The clock keeps publishing through the
-- finalization grace, so this runs on seconds past the end of the
-- shift too: `remaining` goes negative there, matches no mark, and the
-- second passes without a word. Asking to finish on EXACTLY one second
-- is what keeps those seconds from asking again.
function shift.on_second(rules, ev)
    local remaining = rules.shift_minutes * MINUTE - ev.elapsed_seconds
    if remaining == 0 then
        sim.round.finish({ grace_seconds = rules.grace_seconds })
        return
    end
    for _, mark in ipairs(rules.warnings) do
        if remaining == mark then
            -- "in one minute" is its own sentence, not a plural with a
            -- one in it (docs/LOCALIZATION.md §5).
            if mark == MINUTE then
                shift.announce(rules, sim.msg(FINAL_MINUTE, {}))
            else
                shift.announce(rules, sim.msg(WARNING, { minutes = mark // MINUTE }))
            end
        end
    end
end

-- The round entered finalization. The world still ticks through the
-- grace, so this is the last line the crew hears rather than the last
-- thing that happens. It is also the last moment round-scoped state is
-- legal, which is why the shift keeps none: the engine marks the round
-- over as soon as this returns.
function shift.on_end(rules)
    shift.announce(rules, sim.msg(OVER, {}))
end

return shift
