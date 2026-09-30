-- How fast a crewman moves, and when they cannot (docs/BIOLOGY.md).
--
-- `content/bodies/human.luau` declares a `pace` (200 ms a step, +400 ms
-- lying, +200 ms while `crit` holds the body down) and
-- `incapacitated_while = { "crit" }`. The engine prices every step from
-- that and ceils the sum ONCE at the round's rate, so each expectation
-- below is one sum of milliseconds turned into ticks, never a sum of
-- ticks. A `dead` or `undone` line freezes the body instead.
-- The rate is the round's, so it is read after a world exists.
local function ticks_for(ms: number): number
    return math.ceil(ms * t.tick_hz() / 1000 - 1e-9)
end

local WIDTH = 40
local CORRIDOR = string.format(
    [==[(
    name: "corridor",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "%s",
        "#%s#",
        "%s",
    ],
    structures: [(1, 1, "player_spawn")],
)]==],
    string.rep("#", WIDTH + 2),
    string.rep(".", WIDTH),
    string.rep("#", WIDTH + 2)
)

local function new_crewman(): number
    t.world(CORRIDOR, 0)
    local p = t.join()
    t.tick()
    return p
end

-- Hold east every tick for `ticks` ticks and answer the tick number of
-- each step the body took, counting from 1.
local function steps_over(p: number, ticks: number): { number }
    local landed = {}
    local x = t.pos(p)
    for tick = 1, ticks do
        t.move(p, "east")
        t.tick()
        local now = t.pos(p)
        if now ~= x then
            table.insert(landed, tick)
            x = now
        end
    end
    return landed
end

-- The ticks between each pair of consecutive steps: the cadence itself.
local function gaps(landed: { number }): { number }
    local out = {}
    for i = 2, #landed do
        table.insert(out, landed[i] - landed[i - 1])
    end
    return out
end

local function assert_cadence(p: number, ms: number, what: string)
    local cadence = ticks_for(ms)
    local landed = steps_over(p, cadence * 6 + 2)
    assert(#landed >= 5, what .. ": it kept stepping, got " .. #landed)
    for _, gap in ipairs(gaps(landed)) do
        assert(gap == cadence, what .. ": one step per " .. cadence .. " ticks, got " .. gap)
    end
end

-- ---------------------------------------------------------------
-- Standing: the plan's own base, tg's run step kept at 200 ms.
-- ---------------------------------------------------------------
local walker = new_crewman()
assert_cadence(walker, 200, "a standing crewman")

-- ---------------------------------------------------------------
-- Lying: `lying_add_ms` on top, the whole sum ceiled once. A crewman who
-- lies down of their own accord is not incapacitated, so no more.
-- ---------------------------------------------------------------
local prone = new_crewman()
t.rest(prone, true)
assert(assert(t.body(prone)).posture == "lying", "resting puts them on the deck")
assert_cadence(prone, 200 + 400, "a crewman lying down")

-- ---------------------------------------------------------------
-- `crit`: held down and crawling at the lying add AND the incapacitated
-- add (tg stacks them, combat.dm:130), unsteerable but not frozen.
-- ---------------------------------------------------------------
local hurt = new_crewman()
-- HEALTH_THRESHOLD_CRIT is 0 of a 100-point bar: a hundred of brute puts
-- them exactly on the line and no further.
t.set_health(hurt, { brute = 100 })
local crit = assert(t.body(hurt))
assert(crit.thresholds[1] == "crit" and #crit.thresholds == 1, "on the crit line only")
assert(crit.controllable, "the pack has not frozen a crit body")
assert(crit.posture == "lying", "held down")
assert_cadence(hurt, 200 + 400 + 200, "a crewman in crit")

-- ...and healed back over the line they stand and walk at the base again:
-- the engine derived the crawl from the latch, so nothing has to be
-- written to take it off. The last crawling step's cooldown was priced at
-- the crawl, so let it run out before timing a walking one.
t.set_health(hurt, { brute = 0 })
assert(#assert(t.body(hurt)).thresholds == 0, "no line latched")
assert(assert(t.body(hurt)).posture == "standing", "they are up")
t.run_ticks(ticks_for(200 + 400 + 200))
assert_cadence(hurt, 200, "a crewman healed out of crit")

-- ---------------------------------------------------------------
-- A stop freezes: `dead` writes `controllable = false`, and a frozen
-- body takes no step at all.
-- ---------------------------------------------------------------
local gone = new_crewman()
-- HEALTH_THRESHOLD_DEAD is -1 of the same bar.
t.set_health(gone, { brute = 400 })
local dead = assert(t.body(gone))
assert(not dead.controllable and not dead.animate, "past `dead` the pack has frozen and stopped it")
local before = t.pos(gone)
local landed = steps_over(gone, ticks_for(200 + 400 + 200) * 3)
assert(#landed == 0, "a frozen body takes no step, took " .. #landed)
assert(t.pos(gone) == before, "and stays where it fell")
