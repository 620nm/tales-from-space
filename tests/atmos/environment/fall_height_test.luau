-- A crewman who steps off a floor onto an upper-level Open substrate falls
-- to the level below: one `level_changed` row via "fall" over one level, then
-- one `physical_motion_landed` row no sooner than the drop allows.
--
-- The drop is one tile height, `simulation.tile.height_m` (`t.tile`), here 3 m
-- (content/capabilities.luau), under standard gravity 9.80665 m/s2 (the
-- terrestrial profile below). Free fall takes sqrt(2h/g) = 0.7823 s, which is
-- 15.65 ticks at the pack's 20 Hz; clock.deadline_ticks rounds that up to 16
-- integration steps. The engine's `dropped_motion_lands_after_free_fall_of_its_height`
-- pins 16 advances for 3 m at 20 Hz, and the commit tick is advance one: the
-- landing row sits 15 ticks after the `level_changed` row. A 1 m tile lands on
-- advance 9, below this minimum.
local clock = require("@helpers/clock")

local tile = t.tile()
assert(tile, "the pack declares simulation.tile")
local FALL_HEIGHT_M = tile.height_m
local STANDARD_GRAVITY_M_S2 = 9.80665

t.world(
    [==[(
    name: "open space fall",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [],
        ),
        (
            rows: [
                "#####",
                "#.o.#",
                "#####",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)

-- The booted round's rate, read after the world exists (`t.tick_hz` needs one).
local MIN_LANDING_TICKS = clock.deadline_ticks(math.sqrt(2.0 * FALL_HEIGHT_M / STANDARD_GRAVITY_M_S2))

local p = t.join()
t.run_ticks(4)
assert(#t.ledger_rows("level_changed") == 0, "nothing has changed level before the step")

t.move(p, "east")
t.run_seconds(3)

local falls = t.ledger_rows("level_changed")
assert(#falls == 1, "one level_changed row for one fall, got " .. #falls)
local fall = falls[1]
assert(fall.via == "fall", "the open tile drops the body, got via " .. tostring(fall.via))
assert(fall.levels == 1, "one level crossed, got " .. tostring(fall.levels))
assert(#t.ledger_rows("level_step_refused") == 0, "the drop is admitted, not refused")

local landings = t.ledger_rows("physical_motion_landed")
assert(#landings == 1, "one landing for one fall, got " .. #landings)
-- Integration steps: the commit tick already ran advance one.
local advances = landings[1].tick - fall.tick + 1
assert(
    advances >= MIN_LANDING_TICKS,
    "a 3 m drop lands no sooner than " .. MIN_LANDING_TICKS .. " steps, landed on " .. advances
)

local x, y = t.pos(p)
assert(x == 2 and y == 1, "the landing keeps the tile, got (" .. x .. ", " .. y .. ")")
