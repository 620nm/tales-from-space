-- A blank tile starts with its environment's air, not the station's: on a
-- cold world it holds the cold outside air even where the map does not say
-- `outdoors`, and in a space basement a blank pocket holds nothing. A body
-- in no more gas than the move quantum, a pile the air leaves at rest, reads
-- no pressure and no temperature on its HUD (the engine's docs/BIOLOGY.md).
-- Reads run right after the world loads, before any air moves.
local ROOM_K = 293.15 -- the station's round air (content/blends/breathable_air.luau)
local COLD_K = 259.15 -- content/blends/refrigerated_air.luau
local TOLERANCE_K = 0.01

-- 1. A cold world: the blank ground round the station is cold outside air.
t.world(
    [==[(
    name: "blank cold ground",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(259.15)),
    legend: {
        ' ': (composition: ()),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: [
                "       ",
                " ##### ",
                " #...# ",
                " ##### ",
                "       ",
            ],
            structures: [(3, 2, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)
assert(t.environment().id == "cold_outdoors", "259.15 K picks the cold ground, got " .. t.environment().id)
local blank_k = assert(t.room_temperature(0, 0), "the blank tile holds air")
assert(math.abs(blank_k - COLD_K) < TOLERANCE_K, "a blank tile starts with the cold outside air, got " .. blank_k)
assert(assert(t.room_pressure(0, 0)) > 100, "at the outside air's pressure")
assert(math.abs(assert(t.room_temperature(3, 2)) - ROOM_K) < TOLERANCE_K, "the sealed room keeps the station's air")

-- 2. A space basement: the blank pocket over a basement wall holds nothing,
-- while the deck beside it keeps the station's air.
t.world(
    [==[(
    name: "blank space pocket",
    levels_below_ground: 1,
    environment: (kind: Exact(space)),
    legend: {
        ' ': (composition: ()),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#.###",
                "#####",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
        (
            rows: [
                "#####",
                "#.# #",
                "#####",
            ],
            structures: [],
        ),
    ],
)]==],
    0,
    "free_build"
)
assert(t.environment().kind == "space", "the map rolls a space environment: " .. t.environment().id)
local pocket_kpa = assert(t.room_pressure(3, 1), "the blank pocket is a cell")
assert(pocket_kpa < 0.01, "a blank pocket in space starts empty, got " .. pocket_kpa .. " kPa")
assert(next(t.room_gas(3, 1) or {}) == nil, "with no gas in it at all")
assert(assert(t.room_pressure(1, 1)) > 100, "the deck keeps the station's air")

-- 3. The HUD: a body in a wisp, or in a pile over the sweep floor but under
-- the move quantum (0.02 mol/m^3, half of 0.0416), reads no pressure and no
-- temperature; a body in the station's air reads both.
t.world(
    [==[(
    name: "the wisp",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    blends: {
        "wisp": (rows: [("n2:gas", 0.000001)], temperature_k: 293.15, amount: per_m3),
        "pile": (rows: [("n2:gas", 0.02)], temperature_k: 293.15, amount: per_m3),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.#.#.#",
                "#######",
            ],
            structures: [
                (1, 1, "player_spawn", { "jobs": "assistant" }),
                (3, 1, "player_spawn", { "jobs": "engineer" }),
                (5, 1, "player_spawn", { "jobs": "medic" }),
            ],
            painted: [(3, 1, "wisp"), (5, 1, "pile")],
        ),
    ],
)]==],
    0
)
-- The readouts are pushed when a pool moves, so nudge one on each body.
t.set_breathing(false)
local aired = t.join("assistant")
local starved = t.join("engineer")
local stranded = t.join("medic")
t.run_ticks(2)
t.set_health(aired, { brute = 1 })
t.set_health(starved, { brute = 1 })
t.set_health(stranded, { brute = 1 })
t.run_ticks(1)
local lit = assert(t.vitals(aired), "a body in air has a HUD")
assert(lit.pressure ~= nil and lit.temperature ~= nil, "and it reads the air's pressure and temperature")
local dark = assert(t.vitals(starved), "a body in a wisp has a HUD")
assert(dark.pressure == nil, "a wisp reads no pressure, got " .. tostring(dark.pressure))
assert(dark.temperature == nil, "and no temperature, got " .. tostring(dark.temperature))
local pile_kpa = assert(t.room_pressure(5, 1), "the pile is a cell")
assert(pile_kpa > 0.01, "the pile is really there, got " .. pile_kpa .. " kPa")
local resting = assert(t.vitals(stranded), "a body in a pile has a HUD")
assert(resting.pressure == nil, "a pile under the move quantum reads no pressure, got " .. tostring(resting.pressure))
assert(resting.temperature == nil, "and no temperature, got " .. tostring(resting.temperature))
