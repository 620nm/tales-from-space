-- The air a map PAINTS into its rooms: named recipes, and one entry per
-- tile naming one (docs/ATMOS.md 11).
--
-- The point of the indirection is authoring rather than physics: a
-- recipe is written once and painted many times, so two rooms meant to
-- hold the same air hold the same air by construction rather than by
-- coincidence. That is what the first block below shows -- two tiles
-- naming one recipe, agreeing to the mole.
--
-- The recipes are this MAP's own words. Nothing here names a preset the
-- content pack ships: which air a pack offers is content, and a spec
-- that spelled one would be asserting what a game happens to ship
-- rather than what the engine does with what it is given.

local COLD_K = 259.15
local T20C = 293.15
local R_GAS = 8.314
local TILE_M3 = 1.0
local ONE_ATM_PA = 101325.0

-- Moles of ideal gas filling one tile at a pressure and a temperature.
-- The same pV/RT the map format converts through, spelled here so the
-- map below can be written in the numbers a mapper would reason in.
local function tile_moles(pa, k)
    return pa * TILE_M3 / (R_GAS * k)
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function total(x, y)
    local sum = 0.0
    for _, moles in pairs(t.room_gas(x, y) or {}) do
        sum = sum + moles
    end
    return sum
end

local warm = tile_moles(ONE_ATM_PA, T20C)
local cold = tile_moles(ONE_ATM_PA, COLD_K)

-- A sealed row of five: two tiles of walk-in cold room, one pumped-down
-- chamber, and two the mapper left alone.
local MAP = [==[
(
    name: "painted air",
    legend: {
        '#': (turf: Wall),
        '.': (turf: Floor),
    },
    rows: [
        "#######",
        "#.....#",
        "#######",
    ],
    spawns: [(5, 1)],
    blends: {
        "walk_in": (rows: [("o2", ]==] .. cold * 0.21 .. [==[), ("n2", ]==] .. cold * 0.79 .. [==[)], temperature_k: ]==] .. COLD_K .. [==[, amount: per_tile),
        "pumped_down": (temperature_k: 2.7, amount: per_tile),
    },
    painted: [(1, 1, "walk_in"), (2, 1, "walk_in"), (3, 1, "pumped_down")],
)
]==]

t.world(MAP)

-- One recipe, two tiles, one answer. Read before a single tick, because
-- after one the two are already exchanging with each other.
local a, b = total(1, 1), total(2, 1)
near(a, b, 1e-6, "two tiles of one recipe hold the same air")
near(a, cold, 0.01, "and it is the quantity the recipe named")
near(t.room_temperature(1, 1), COLD_K, 0.01, "the walk-in opens cold")
near(t.room_pressure(1, 1), 101.325, 0.05, "at one atmosphere, because that is what those moles are")

-- The tiles nobody painted opened on standard air, at room temperature
-- -- so "ordinary air, but cold" cost the map a temperature and nothing
-- else.
near(total(4, 1), warm, 0.01, "an unpainted tile is standard air")
near(t.room_temperature(4, 1), T20C, 0.5, "at room temperature")

-- A recipe for nothing is a vacuum, and it is an INTERIOR one: the room
-- beside it flows in, which is exactly what a hole in the hull would
-- not let it do.
near(total(3, 1), 0.0, 1e-6, "a recipe with no gases holds nothing")
assert(t.room_pressure(3, 1) < 0.001, "and reads as vacuum: " .. t.room_pressure(3, 1))

t.run_seconds(60)

assert(t.room_pressure(3, 1) > 1.0, "the sealed row fills the empty tile")
local left, right = t.room_pressure(2, 1), t.room_pressure(4, 1)
near(left, right, 5.0, "and a sealed row equalises rather than venting")
