-- A blank tile above ground is open sky; on a planet that is the planet's air.
-- Plating (`station_base`, `substrate_seal`) closes it (the engine's
-- `docs/mapping/environment.md` "Exposure"; the engine's `docs/matter-world/environment.md`).
--
-- Level 0: room A (x 1..3) and room B (x 5..7), two sealed rooms of standard
-- air. Level 1: a blank `Inherit` roof over A, plating over B, and a wall over
-- every level-0 wall so each roof is bounded by its own room's footprint.
-- Bare `(x, y)` reads are level 0; the level-1 roof is edited with a level.
local atmos_cell = require("@helpers/atmos_cell")

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

local ONE_ATM_KPA = 101.325
local READ_TOLERANCE_KPA = 0.05 -- room_air_test.luau:73-79, a read at one atmosphere
local MOLES_TOLERANCE = 1e-6 -- room_air_test.luau:70-72, "to the mole"
local STATION_DENSITY = atmos_cell.density_mol_per_m3(101325.0, 293.15)
local START_OXYGEN = atmos_cell.cell_moles(STATION_DENSITY * 0.21)
local START_NITROGEN = atmos_cell.cell_moles(STATION_DENSITY * 0.79)

-- `%s` takes the map's own fixed-air preference and recipe, or nothing.
local MAP = [==[(
    name: "open sky planet",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(259.15)%s),
    blends: {%s},
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
)]==]

local function gas(tile, key: string): number
    return (assert(t.room_gas(tile.x, tile.y))[key] or 0)
end

local function oxygen_in_room_a(): number
    local sum = 0.0
    for _, tile in ipairs(ROOM_A) do
        sum = sum + gas(tile, "o2")
    end
    return sum
end

-- ---------------------------------------------------------------
-- THE PLANET'S AIR DIFFERS ONLY IN MIX.
--
-- The map fixes the ambient recipe: pure nitrogen at station pressure and
-- temperature, so the only thing sky exchange can change in room A is what the
-- air is made of. (Deck coupling, the engine's docs/matter-world/thermal.md 5b, holds a
-- room's air near its deck's temperature, so a cold planet's temperature is
-- only a direction -- see the last block.)
-- ---------------------------------------------------------------
local NITROGEN_AIR = '"nitrogen_air": (rows: [("n2", '
    .. STATION_DENSITY
    .. ")], temperature_k: 293.15, amount: per_m3)"
t.world(string.format(MAP, ', atmosphere_blend: Some("nitrogen_air")', NITROGEN_AIR), 0, "free_build")
local atmosphere = assert(assert(t.environment().profile).atmosphere)

-- Exchange acts on the roof's cell only (the engine's docs/matter-world/environment.md
-- "Exchange law": half-life h = air_half_life_s), and room A's cell shares its
-- gas with the roof cell, so the column's oxygen halves every 2h. Taking room
-- A's share of the column as the whole column, A holds at most
-- start * 2^(-SETTLE_S / 2h): the dropped factor 1/2 is the margin for the
-- roof cell's finite mixing lag.
local SETTLE_S = 600
local OXYGEN_BOUND = START_OXYGEN * math.pow(2, -SETTLE_S / (2 * atmosphere.air_half_life_s))

for _, tile in ipairs(ROOM_A) do
    local oxygen = gas(tile, "o2")
    assert(math.abs(oxygen - START_OXYGEN) < MOLES_TOLERANCE, "room A starts on station air")
end
local b_start = gas(ROOM_B_TILE, "o2")
assert(math.abs(b_start - START_OXYGEN) < MOLES_TOLERANCE, "room B starts on station air")

t.run_seconds(SETTLE_S)
for _, tile in ipairs(ROOM_A) do
    assert(
        gas(tile, "o2") < OXYGEN_BOUND,
        "open sky flushes room A's oxygen toward the planet's: (" .. tile.x .. ", " .. tile.y
            .. ") holds " .. gas(tile, "o2") .. " of " .. START_OXYGEN .. " mol"
    )
    assert(gas(tile, "n2") > START_NITROGEN, "and fills it with the planet's nitrogen")
    local pressure = assert(t.room_pressure(tile.x, tile.y))
    assert(
        math.abs(pressure - ONE_ATM_KPA) < READ_TOLERANCE_KPA,
        "the planet's air is at station pressure, so A swaps air without venting: " .. pressure
    )
end

-- Plating over B kept its air: nothing leaves a sealed room.
local b_pressure = assert(t.room_pressure(ROOM_B_TILE.x, ROOM_B_TILE.y))
assert(
    math.abs(b_pressure - ONE_ATM_KPA) < READ_TOLERANCE_KPA,
    "room B holds one atmosphere: " .. b_pressure
)
assert(
    math.abs(gas(ROOM_B_TILE, "o2") - START_OXYGEN) < MOLES_TOLERANCE,
    "plating over room B keeps its oxygen: " .. gas(ROOM_B_TILE, "o2")
)
assert(
    math.abs(gas(ROOM_B_TILE, "n2") - START_NITROGEN) < MOLES_TOLERANCE,
    "plating over room B keeps its nitrogen: " .. gas(ROOM_B_TILE, "n2")
)

-- Plating the sky tiles at runtime closes room A: a tracer of oxygen put into
-- it is still there after the span that flushed the original oxygen.
local TRACER_MOLES_PER_TILE = 10.0
for _, tile in ipairs(ROOM_A) do
    assert(
        t.set_composition(tile.x, tile.y, "plating", ROOF_LEVEL),
        "plating goes onto the sky tile at (" .. tile.x .. ", " .. tile.y .. ")"
    )
    assert(t.foul_room(tile.x, tile.y, "o2", TRACER_MOLES_PER_TILE), "the tracer reaches the room")
end
local tracer_start = oxygen_in_room_a()
t.run_seconds(SETTLE_S)
local tracer_end = oxygen_in_room_a()
assert(
    math.abs(tracer_end - tracer_start) < MOLES_TOLERANCE,
    "a plated roof keeps the tracer: " .. tracer_start .. " -> " .. tracer_end .. " mol"
)

-- ---------------------------------------------------------------
-- THE SHIPPED COLD PLANET.
--
-- Its ambient is 259.15 K. Room A's deck starts at station temperature and
-- re-warms A's air (the engine's docs/matter-world/thermal.md 5b), so A settles
-- between the two and stays far from 259.15 K over this block's span; the
-- claim is direction. A is cooler than station air by more than the solver's
-- own thermal tolerance (MIN_TEMP_DELTA, 0.5 K: the engine's docs/matter-world/environment.md
-- "Activity and scheduling") and warmer than the planet. B, plated, keeps
-- station temperature within the 0.01 K that terrestrial_environment_test.luau
-- reads room temperature to.
-- ---------------------------------------------------------------
local COLD_K = 259.15
local STATION_K = 293.15
local MIN_TEMP_DELTA_K = 0.5

t.world(string.format(MAP, "", ""), 0, "free_build")
local cold = assert(assert(t.environment().profile).atmosphere)
assert(cold.blend == "refrigerated_air", "the shipped planet is cold")
t.run_seconds(cold.heat_half_life_s) -- one heat half-life of the profile
for _, tile in ipairs(ROOM_A) do
    local kelvin = assert(t.room_temperature(tile.x, tile.y))
    assert(
        kelvin < STATION_K - MIN_TEMP_DELTA_K and kelvin > COLD_K,
        "open sky cools room A toward the planet: (" .. tile.x .. ", " .. tile.y
            .. ") is " .. kelvin .. " K"
    )
end
local b_kelvin = assert(t.room_temperature(ROOM_B_TILE.x, ROOM_B_TILE.y))
assert(
    math.abs(b_kelvin - STATION_K) < 0.01,
    "plated room B keeps station temperature: " .. b_kelvin
)
