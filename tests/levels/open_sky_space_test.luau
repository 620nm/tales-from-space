-- A blank tile above ground is open sky; in orbit that is vacuum. Plating
-- (`station_base`, `substrate_seal`) closes it, and removing the plating
-- reopens it (the engine's `docs/content-schema/compositions.md` "Tile
-- values and replacement"; the engine's `docs/MATTER-WORLD.md` Vertical openings).
--
-- Level 0: room A (x 1..3) and room B (x 5..7), two sealed rooms of standard
-- air. Level 1: a blank, `Inherit` roof over A, plating over B. Level 1 is a
-- wall over every level-0 wall, so no sky tile touches a plated one sideways
-- and each roof is bounded by its own room's footprint. The kind and zero
-- gravity pin the sunless skies (`dead_space`, `microgravity`): deep space,
-- no sunlight, so only the sky link acts on air.
-- Bare `(x, y)` reads are level 0; the level-1 roof is edited with a level.
local atmos_cell = require("@helpers/atmos_cell")

t.world(
    [==[(
    name: "open sky orbit",
    tags: ["space"],
    environment: (kind: Exact(space), gravity_m_s2: Exact(0.0)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        's': (composition: ()),
        'p': (composition: (components: [(component: "station_base")])),
    },
    levels: [
        (
            rows: [
                "#########",
                "#...#...#",
                "#...#...#",
                "#########",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
        (
            rows: [
                "#########",
                "#sss#ppp#",
                "#sss#ppp#",
                "#########",
            ],
            structures: [],
        ),
    ],
)]==],
    0,
    "free_build"
)
assert(
    t.environment().kind == "space" and t.environment().insolation == 0,
    "the map pins sunless deep space: " .. t.environment().id
)

local ROOF_LEVEL = 1
local ROOM_A = {
    { x = 1, y = 1 },
    { x = 2, y = 1 },
    { x = 3, y = 1 },
    { x = 1, y = 2 },
    { x = 2, y = 2 },
    { x = 3, y = 2 },
}
local ROOM_B_TILE = { x = 5, y = 1 }

-- One atmosphere (breathable_air is p/RT at 101325 Pa, 293.15 K), and the
-- tolerance of a pressure read at that density: room_air_test.luau:73-79.
local ONE_ATM_KPA = 101.325
local READ_TOLERANCE_KPA = 0.05
local STATION_DENSITY = atmos_cell.density_mol_per_m3(101325.0, 293.15)

-- The hazard line (20 kPa) and the time a 5x5 room takes to cross it through
-- ONE 1-tile hole to space, 8 s (the engine's docs/matter-world/bulk-flow.md "Pace" and
-- crates/lunatic-matter/src/world/tests/bulk/vent_pace.rs). Room A is
-- 6 tiles with a hole over every tile, so it crosses sooner; the bound is a
-- ceiling on the engine's own slowest comparable row, not a fit to this run.
local HAZARD_KPA = 20.0
local VENT_SPAN_S = 8

local function pressure_a(): { number }
    local pressures = {}
    for _, tile in ipairs(ROOM_A) do
        table.insert(pressures, assert(t.room_pressure(tile.x, tile.y)))
    end
    return pressures
end

local function assert_room_a_vented(why: string)
    for index, pressure in ipairs(pressure_a()) do
        local tile = ROOM_A[index]
        assert(
            pressure < HAZARD_KPA,
            why .. ": (" .. tile.x .. ", " .. tile.y .. ") holds " .. pressure .. " kPa"
        )
    end
end

local function assert_room_a_holds(why: string)
    for index, pressure in ipairs(pressure_a()) do
        local tile = ROOM_A[index]
        assert(
            math.abs(pressure - ONE_ATM_KPA) < READ_TOLERANCE_KPA,
            why .. ": (" .. tile.x .. ", " .. tile.y .. ") holds " .. pressure .. " kPa"
        )
    end
end

-- Both rooms start on standard air: the premise every later assert leans on.
assert_room_a_holds("room A starts at one atmosphere")
local b_start = assert(t.room_pressure(ROOM_B_TILE.x, ROOM_B_TILE.y))
assert(
    math.abs(b_start - ONE_ATM_KPA) < READ_TOLERANCE_KPA,
    "room B starts at one atmosphere, got " .. b_start
)

-- 1 + 2: the blank roof vents A; the plated roof keeps B.
t.run_seconds(VENT_SPAN_S)
assert_room_a_vented("open sky over room A vents it within " .. VENT_SPAN_S .. " s")
local b_after = assert(t.room_pressure(ROOM_B_TILE.x, ROOM_B_TILE.y))
assert(
    math.abs(b_after - b_start) < READ_TOLERANCE_KPA,
    "plating over room B keeps its air: " .. b_start .. " -> " .. b_after .. " kPa"
)

-- 3: plating the sky tiles at runtime closes them. Refill every tile of A to
-- standard air (a level-0 precondition) and A keeps that pressure for the same span.
local function refill_room_a()
    for _, tile in ipairs(ROOM_A) do
        local oxygen = atmos_cell.cell_moles(STATION_DENSITY * 0.21)
        local nitrogen = atmos_cell.cell_moles(STATION_DENSITY * 0.79)
        assert(t.foul_room(tile.x, tile.y, "o2", oxygen), "oxygen reaches the room")
        assert(t.foul_room(tile.x, tile.y, "n2", nitrogen), "nitrogen reaches the room")
    end
end

for _, tile in ipairs(ROOM_A) do
    assert(
        t.set_composition(tile.x, tile.y, "plating", ROOF_LEVEL),
        "plating goes onto the sky tile at (" .. tile.x .. ", " .. tile.y .. ")"
    )
end
refill_room_a()
t.run_seconds(VENT_SPAN_S)
assert_room_a_holds("plated roof keeps the refilled room for " .. VENT_SPAN_S .. " s")

-- 4: removing the plating from one tile reopens the sky there; A vents again.
assert(t.set_composition(1, 1, "bare", ROOF_LEVEL), "the plating comes off one sky tile")
t.run_seconds(VENT_SPAN_S)
assert_room_a_vented("one reopened sky tile vents the room within " .. VENT_SPAN_S .. " s")
