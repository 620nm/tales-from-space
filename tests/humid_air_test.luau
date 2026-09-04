-- A room with the humidity up.
--
-- `content/blends/humid_air.luau` is standard air with half a mole of
-- water vapour on every tile. It is chosen between two lines the pack
-- and the engine each own one of, and this spec is where the engine's
-- half is checked against the engine rather than against the header's
-- own arithmetic:
--   * over water's `visible.moles`, a quarter mole, so the room reads
--     as fogged rather than as clear air with a number in it
--   * under the density water condenses out at, which the engine
--     derives from water's boil and latent heat -- so the fog is still
--     there a shift later instead of raining out on the first pass
--
-- If the engine's curve ever disagreed with the header's formula, this
-- is the spec that would go red: the pack's claim is that half a mole
-- STAYS a gas, and only the engine can say whether it does.

t.world([==[(
    name: "steam bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    blends: {
        // The pack's blend, in the map's spelling. The `:gas` suffix is
        // said out loud because water rests LIQUID at 20 C, and a room
        // painted with a puddle in the air is not what this means.
        "humid_air": (rows: [("o2", 8.730437114532117), ("n2", 32.84307295466844), ("water:gas", 0.5)], temperature_k: 293.15, amount: per_tile),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    painted: [(1, 1, "humid_air"), (2, 1, "humid_air"), (3, 1, "humid_air")],
)]==], 0)

local p = t.join()
t.tick()

local PER_TILE = 0.5
local TILES = 3
local VISIBLE_MOLES = 0.25

local function room_water()
    local total = 0.0
    for x = 1, TILES do
        total = total + (t.room_gas(x, 1).water or 0.0)
    end
    return total
end

-- ---------------------------------------------------------------
-- Painted, and it landed where it was put: half a mole a tile, as
-- GAS. A tile is a cubic metre, so a density painted on one is the
-- amount standing in it.
-- ---------------------------------------------------------------
local wet = room_water()
assert(math.abs(wet - PER_TILE * TILES) < 1e-6,
    "half a mole a tile, three tiles: " .. wet)
assert(t.room_gas(2, 1).water > VISIBLE_MOLES,
    "and over the line water is visible from, so the room reads as fogged")

-- ---------------------------------------------------------------
-- Leave it. Nothing rains out. The engine's own saturation curve is
-- above this density at room temperature, so the vapour is still
-- vapour half a minute later -- the pack picked the number, the
-- engine is what agrees with it.
-- ---------------------------------------------------------------
t.run_ticks(700)

local later = room_water()
assert(later > wet * 0.99,
    ("the fog did not rain out: %g -> %g"):format(wet, later))
assert(t.room_temperature(2, 1) > 290.0,
    "and the room is still the room it was: " .. t.room_temperature(2, 1))

-- ---------------------------------------------------------------
-- The station ships one: the chem bench, under a burner that has
-- been going. Same blend, same claim, on the map a shift opens on.
-- ---------------------------------------------------------------
t.world_file("chillstation.ron", 0)
t.join()
t.tick()

local bench = t.room_gas(19, 5).water
assert(bench ~= nil and bench > VISIBLE_MOLES,
    "the air over the chem bench is damp: " .. tostring(bench))
