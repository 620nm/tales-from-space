-- What a liquid leaves behind: spirit wets, water beads.
--
-- Surface tension against the angle a liquid stands at decides how thin
-- a film can get before it stops moving -- h_min = 2*sqrt(sigma/rho g)
-- *sin(theta/2), docs/matter-world/flow.md. Water on painted deck
-- (72.8 mN/m, 75 degrees) stops at 3.3 mm; ethanol (22.1 mN/m, 10
-- degrees) lies almost flat and stops at 0.29 mm. So the same bottle of
-- spirit reaches further down a corridor and leaves less behind it,
-- and that ORDERING is the claim. Not the ratio: what actually stops a
-- frontier is the film plus whatever the millilitre quantum freezes on
-- top of it, and that second term is worth more than a millimetre to
-- either of them. The films differ elevenfold; the spills do not.
--
-- Two identical twenty-tile corridors, twenty litres poured on the
-- first tile of each. No exact tile count is asserted -- the count is
-- what the quantum leaves, and the spec that pins it is a spec that
-- breaks when the epsilon moves.

local CORRIDOR = [==[(
    name: "wetting corridor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######################",
        "#....................#",
        "######################",
    ],
    spawns: [(1, 1)],
    blends: {
        "pour": (rows: [("%s", %s), ("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: total),
    },
    painted: [(1, 1, "pour")],
)]==]

local TILES = 20
local PUDDLE_L = 0.05 -- 50 mL: a wet tile somebody would fetch a mop for
local SETTLE = 1600 -- ticks, long past the surge and into the creep

-- 20 L of each, which is where the two arithmetics part:
--   water   18.015 g/mol / 1.0   g/mL = 18.02 mL/mol -> 55.51 mol/L -> 1110.2 mol
--   ethanol 46.07  g/mol / 0.789 g/mL = 58.39 mL/mol -> 17.13 mol/L ->  342.6 mol
-- The air rows are the same 21/79 at 20 C in both corridors (41.573
-- mol over a cubic metre is 101.325 kPa), because a `total` blend is
-- the tile's whole contents and neither corridor may open airless.
local function pour(key, moles)
    t.world(CORRIDOR:format(key, moles), 0)
    t.join()
    t.tick()
end

local function held(key, x)
    local standing = t.room_liquid(x, 1)
    return (standing and standing[key]) or 0
end

-- How far it got: the count of tiles carrying a puddle, and the run has
-- to start at the tile it was poured on and be unbroken, because a
-- liquid crosses tiles rather than appearing on them.
local function reach(key)
    local n = 0
    for x = 1, TILES do
        if held(key, x) > PUDDLE_L then
            assert(n == x - 1, ("%s wet (%d,1) with a dry tile behind it"):format(key, x))
            n = n + 1
        end
    end
    return n
end

local function spread(key, moles)
    pour(key, moles)
    local poured = t.matter_totals().substances[key]
    assert(
        math.abs(poured - moles) < 1e-6,
        ("%s: the blend is what was painted, %.4f mol"):format(key, poured)
    )
    assert(reach(key) == 1, ("%s starts on the one tile it was poured on"):format(key))

    t.run_ticks(SETTLE)
    local tiles, source = reach(key), held(key, 1)
    assert(tiles > 1, ("%s never left the tile it was poured on"):format(key))
    assert(
        math.abs(t.matter_totals().substances[key] - poured) < 1e-6,
        ("%s: every mole is still on the books"):format(key)
    )
    for x = 2, tiles do
        assert(
            held(key, x) <= source + 1e-9,
            ("%s ran uphill: (%d,1) is deeper than the source"):format(key, x)
        )
    end
    return tiles, source
end

local water_tiles, water_source = spread("water", 1110.2)
local spirit_tiles, spirit_source = spread("ethanol", 342.6)

-- ---------------------------------------------------------------
-- SPIRIT GOES FURTHER.
-- ---------------------------------------------------------------
assert(
    spirit_tiles > water_tiles,
    ("ethanol wet %d tiles and water wet %d"):format(spirit_tiles, water_tiles)
)

-- ---------------------------------------------------------------
-- AND LEAVES LESS WHERE IT FELL.
--
-- The same claim from the other end: a liquid that stops thinning at a
-- tenth of the depth keeps a tenth as much on the tile the bottle went
-- over. It is the same twenty litres, so what one end of the corridor
-- does not hold, the other end does.
-- ---------------------------------------------------------------
assert(
    spirit_source < water_source,
    ("ethanol left %.4f L where it fell and water left %.4f L"):format(spirit_source, water_source)
)
