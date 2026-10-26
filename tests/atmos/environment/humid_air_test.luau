-- A room with the humidity up.
--
-- `content/blends/humid_air.luau` is standard air with half a mole of
-- water vapour per cubic metre. It is chosen between two lines the pack
-- and the engine each own one of, and this spec is where the engine's
-- half is checked against the engine rather than against the header's
-- own arithmetic:
--   * over water's `visible.mol_per_m3`, a quarter mole per m3, so the room reads
--     as fogged rather than as clear air with a number in it
--   * under the density water condenses out at, which the engine
--     derives from water's boil and latent heat -- so the fog is still
--     there a shift later instead of raining out on the first pass
--
-- If the engine's curve ever disagreed with the header's formula, this
-- is the spec that would go red: the pack's claim is that half a mole
-- STAYS a gas, and only the engine can say whether it does.

t.world(
    [==[(
    name: "steam bench",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    blends: {
        // The pack's blend, in the map's spelling. The `:gas` suffix is
        // said out loud because water rests LIQUID at 20 C, and a room
        // painted with a puddle in the air is not what this means.
        "humid_air": (rows: [("o2", 8.730437114532117), ("n2", 32.84307295466844), ("water:gas", 0.5)], temperature_k: 293.15, amount: per_m3),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [(1, 1, "player_spawn")],
            painted: [(1, 1, "humid_air"), (2, 1, "humid_air"), (3, 1, "humid_air")],
        ),
    ],
)]==],
    0
)

t.join()
t.tick()

local atmos_cell = require("@helpers/atmos_cell")

-- The blend's vapour density (mol per m3) and water's visibility threshold
-- (mol per m3), each turned into a cell's moles by its 3 m3 volume.
local PER_M3 = 0.5
local TILES = 3
local VISIBLE_PER_M3 = 0.25
local VISIBLE_MOLES = atmos_cell.cell_moles(VISIBLE_PER_M3)

local function room_water()
    local total = 0.0
    for x = 1, TILES do
        total = total + (assert(t.room_gas(x, 1)).water or 0.0)
    end
    return total
end

-- ---------------------------------------------------------------
-- Painted at half a mole per m3 as GAS, so each 3 m3 cell holds
-- atmos_cell.cell_moles(0.5) = 1.5 mol.
-- ---------------------------------------------------------------
local wet = room_water()
assert(
    math.abs(wet - atmos_cell.cell_moles(PER_M3) * TILES) < 1e-6,
    "half a mole per m3, three cells: " .. wet
)
assert(
    assert(t.room_gas(2, 1)).water > VISIBLE_MOLES,
    "and over the line water is visible from, so the room reads as fogged"
)

-- ---------------------------------------------------------------
-- Leave it. Nothing rains out. The engine's own saturation curve is
-- above this density at room temperature, so the vapour is still
-- vapour half a minute later -- the pack picked the number, the
-- engine is what agrees with it.
-- ---------------------------------------------------------------
t.run_seconds(35)

local later = room_water()
assert(later > wet * 0.99, ("the fog did not rain out: %g -> %g"):format(wet, later))
assert(
    assert(t.room_temperature(2, 1)) > 290.0,
    "and the room is still the room it was: " .. assert(t.room_temperature(2, 1))
)
