-- What lies beyond a map's levels is the environment's to say
-- (`beyond` on the profile, the engine's `docs/gamemodes/environment.md`).
-- Every space environment declares `empty` below and `closed` above
-- (`covered_room_open_test.luau` owns the roof), so:
--
--   1. an Open tile on the LOWEST level is legal -- there is nothing under
--      it to land on -- and it vents the room around it to vacuum;
--   2. walking off the side of the map is not: a body steps up to the
--      last tile and stays there. This pack answers no `map.edge`, so the
--      engine's default holds, and it is on the record once per cause per
--      contact rather than once per press (the room venting past the open
--      edge pushes the body too, under its own cause).
--
-- A closed environment keeps refusing Open on the lowest level; that is
-- the engine's fixture test, not a pack behaviour.
local ONE_ATM_KPA = 101.325
local READ_TOLERANCE_KPA = 0.05
local HAZARD_KPA = 20.0
-- A 3-tile room over one hole crosses the hazard line well inside the
-- 8 s a 5x5 room takes through a single hole
-- (open_sky_space_test.luau:VENT_SPAN_S).
local VENT_SPAN_S = 8

-- 1. The hole on the lowest level. Venting needs no weight, so the
-- sandbox's sunless skies do, and no preparation countdown holds the air.
t.world(
    [==[(
    name: "hole in the bottom",
    tags: ["space"],
    environment: (kind: Exact(space)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
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
assert(t.environment().kind == "space", "the map rolls a space environment: " .. t.environment().id)

local start = assert(t.room_pressure(1, 1))
assert(
    math.abs(start - ONE_ATM_KPA) < READ_TOLERANCE_KPA,
    "the room starts at one atmosphere, got " .. start
)
t.run_seconds(VENT_SPAN_S)
for _, x in ipairs({ 1, 3 }) do
    local pressure = assert(t.room_pressure(x, 1))
    assert(
        pressure < HAZARD_KPA,
        "the hole in the lowest level vents the room: (" .. x .. ", 1) holds " .. pressure .. " kPa"
    )
end

-- 2. Off the side of the map.
t.world(
    [==[(
    name: "edge of the map",
    tags: ["space"],
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: [
                "#######",
                "#......",
                "#######",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "space_station"
)
local walker = t.join()
t.run_ticks(4)
assert(#t.ledger_rows("map_edge_reached") == 0, "nobody has reached an edge yet")

-- Eight presses east from x = 1: five steps reach the last tile at x = 6
-- and the rest lean on the edge.
for _ = 1, 8 do
    t.move(walker, "east")
    t.run_ticks(5)
end
local x, y = t.pos(walker)
assert(x == 6 and y == 1, "the body stays on the last tile, got (" .. x .. ", " .. y .. ")")
local seen = {}
for _, row in ipairs(t.ledger_rows("map_edge_reached")) do
    assert(row.direction_x == 1 and row.direction_y == 0, "every row faces east")
    assert(not seen[row.motion], "one row per cause for the whole contact: " .. tostring(row.motion))
    seen[row.motion] = true
end
assert(seen.step, "the steps into the edge are on the record")
