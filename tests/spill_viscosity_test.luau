-- How fast a puddle levels, and what actually sets that.
--
-- The rate is the thin-film gravity law: a link carries
-- mobility * h^3 * head per second, and mobility is rho*g/(3*mu)
-- (docs/matter-world/flow.md). Both terms are knobs a substance file
-- authors, and this spec isolates them one at a time against the same
-- corridor, the same sixty litres and the same settled depth. What is
-- being asserted every time is a TIME, never a residue: where a spill
-- STOPS is the film's business and tests/spill_wetting_test.luau's.
--
--   * Sulfuric acid is syrup -- 24.0 mPa*s against water's 1.002, and
--     only a little denser -- so it takes strictly longer. Viscosity.
--   * Mercury is HALF AGAIN as viscous as water (1.526 mPa*s) and still
--     strictly quicker, because it is 13.5 times denser and density is
--     the other half of the same fraction. Density.
--
-- The corridor is closed at both ends and six tiles long, and sixty
-- litres over six tiles is ten apiece -- far above every film here
-- (water 3.3 mm, acid 1.75 mm, mercury 3.60 mm), so all three level to
-- the same depth and only the clock separates them.

local CORRIDOR = [==[(
    name: "levelling corridor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "########",
    ],
    spawns: [(1, 1)],
    blends: {
        "pour": (rows: [("%s", %s), ("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: total),
    },
    painted: [(1, 1, "pour")],
)]==]

local TILES = 6
local STEP = 10 -- ticks between readings
local PATIENCE = 6000 -- ticks: past this a regression fails rather than hangs

local function held(key, x)
    local standing = t.room_liquid(x, 1)
    return (standing and standing[key]) or 0
end

-- Sixty litres of each, and the arithmetic is molar mass over liquid
-- density, one mole at a time:
--   water   18.015 / 1.00  = 18.02 mL/mol -> 55.51 mol/L -> 3330.60 mol
--   acid    98.08  / 1.83  = 53.60 mL/mol -> 18.66 mol/L -> 1119.49 mol
--   mercury 200.59 / 13.53 = 14.83 mL/mol -> 67.45 mol/L -> 4047.04 mol
-- The 21/79 air rows ride along in all three, because a `total` blend
-- is the tile's whole contents (41.573 mol over a cubic metre is
-- 101.325 kPa) and no corridor here may open airless.
local function run(key, moles)
    t.world(CORRIDOR:format(key, moles), 0)
    t.join()
    t.tick()

    local poured = t.matter_totals().substances[key]
    assert(math.abs(poured - moles) < 1e-6, ("%s: the blend is what was painted"):format(key))
    assert(held(key, 1) > 59.0, ("%s: sixty litres on one tile"):format(key))

    local crossed, levelled = -1, -1
    for elapsed = STEP, PATIENCE, STEP do
        t.run_ticks(STEP)
        local shallow, deep = math.huge, 0.0
        for x = 1, TILES do
            local depth = held(key, x)
            shallow = math.min(shallow, depth)
            deep = math.max(deep, depth)
        end
        if crossed < 0 and held(key, TILES) > 1.0 then
            crossed = elapsed
        end
        if deep - shallow <= 0.05 * deep then
            levelled = elapsed
            break
        end
    end

    assert(crossed > 0, ("%s never reached the far end of the corridor"):format(key))
    assert(levelled > 0, ("%s never levelled: %.4f L still on the source"):format(key, held(key, 1)))
    -- Sixty litres over six tiles, wherever the clock got to.
    for x = 1, TILES do
        assert(
            math.abs(held(key, x) - 10.0) < 0.5,
            ("%s: (%d,1) settled at %.4f L, not ten"):format(key, x, held(key, x))
        )
    end
    assert(
        math.abs(t.matter_totals().substances[key] - poured) < 1e-6,
        ("%s: every mole is still on the books"):format(key)
    )
    return crossed, levelled
end

local water_crossed, water_levelled = run("water", 3330.6)

-- ---------------------------------------------------------------
-- SYRUP TAKES LONGER. (viscosity: 24.0 against 1.002 mPa*s)
--
-- The same spill, the same corridor, the same ten litres a tile at the
-- end of it -- and strictly more ticks to get there, at both marks:
-- the frontier reaching the far wall, and the whole corridor coming
-- level. The engine's stability cap holds the first surge to the same
-- speed for everything, so the ratio here is smaller than the ratio of
-- the viscosities; the ORDER is what the law promises.
-- ---------------------------------------------------------------
local acid_crossed, acid_levelled = run("sulfuric_acid", 1119.49)
assert(
    acid_crossed > water_crossed,
    ("acid crossed in %d ticks and water in %d"):format(acid_crossed, water_crossed)
)
assert(
    acid_levelled > water_levelled,
    ("acid levelled in %d ticks and water in %d"):format(acid_levelled, water_levelled)
)

-- ---------------------------------------------------------------
-- AND WEIGHT IS THE OTHER HALF. (density: 13.53 against 1.0 g/mL)
--
-- Mercury is the counter-example that stops "thicker is slower" from
-- being the whole story. It is more viscous than water and it still
-- outruns water, because rho*g/(3*mu) is nine times water's when the
-- liquid is thirteen times heavier. Beading is what mercury does to
-- the FILM (485.5 mN/m at 140 degrees is the thickest on this shelf);
-- it is not what it does to the clock.
-- ---------------------------------------------------------------
local mercury_crossed, mercury_levelled = run("mercury", 4047.04)
assert(
    mercury_crossed < water_crossed,
    ("mercury crossed in %d ticks and water in %d"):format(mercury_crossed, water_crossed)
)
assert(
    mercury_levelled < water_levelled,
    ("mercury levelled in %d ticks and water in %d"):format(mercury_levelled, water_levelled)
)
