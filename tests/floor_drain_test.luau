-- The floor drain: the one thing on this station that takes standing
-- water off the deck, and the two things it will not do.
--
-- A drain is a matter SINK (content/structures/floor_drain.luau,
-- ../lunatic/docs/content-schema/structures.md): half a litre a second
-- off the tile it stands on, spent on the liquid standing ABOVE the
-- film and nothing else. So it is a rate somebody can outrun, it
-- leaves a damp deck rather than a dry one, and it does not reach past
-- its own tile.
--
-- What it takes leaves the world through the engine's `drained`
-- register, which is inside `t.matter_totals()` -- so the tile empties
-- and the books still balance, and a drain that quietly deleted moles
-- would fail here rather than in a conservation audit six efforts from
-- now.

local FILM_L = 3.317 -- water on painted deck, 2*sqrt(sigma/rho g)*sin(theta/2)
local RATE_LPS = 0.5 -- content/structures/floor_drain.luau

-- Ten litres, which is 555.10 mol: 18.015 g/mol over 1.0 g/mL is 55.51
-- mol/L. The air rows ride along because a `total` blend is the tile's
-- whole contents -- 41.573 mol over a cubic metre is 101.325 kPa at
-- 20 C, the arithmetic content/blends/standard_air.luau spells out.
local SPILL = [==[
    blends: {
        "spill_10l": (rows: [("water", 555.10), ("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: total),
    },]==]

local function litres(x)
    local standing = t.room_liquid(x, 1)
    return (standing and standing.water) or 0
end

-- ---------------------------------------------------------------
-- HALF A LITRE A SECOND, AND THEN IT STOPS.
--
-- A sealed pocket with the grating in the floor of it and ten litres
-- standing on the grating, so nothing can level away and the only
-- thing happening is the drain.
--
-- The arithmetic is the whole assertion. Ten litres is 6.68 above the
-- film; at half a litre a second that is 13.4 seconds, and this engine
-- runs twenty ticks to the second, so 267 ticks. Then the tile is the
-- film and the drain has nothing left it is allowed to take.
-- ---------------------------------------------------------------
t.world([==[(
    name: "a grating in a pocket",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    spawns: [(1, 1)],
    structures: [(1, 1, "floor_drain")],]==] .. SPILL .. [==[
    painted: [(1, 1, "spill_10l")],
)]==], 0)

t.join()
t.tick()

assert(t.structure_at(1, 1).id == "floor_drain", "the grating is in the deck")
local POURED = t.matter_totals().substances.water
local spilled = litres(1)
assert(spilled > 9.99 and spilled < 10.01, ("ten litres on the grating: %.4f L"):format(spilled))

-- Five seconds of draining, then five more: a straight line, not a
-- curve. A sink that emptied proportionally would fall fastest while
-- it was fullest and never reach the film at all.
t.run_ticks(100)
local at_five = litres(1)
t.run_ticks(100)
local at_ten = litres(1)
local measured = (at_five - at_ten) / 5.0
assert(
    math.abs(measured - RATE_LPS) < 0.02,
    ("it drains at half a litre a second: %.4f L/s"):format(measured)
)

-- And two hundred more ticks finds the film, which is where it stops.
t.run_ticks(200)
local left = litres(1)
assert(
    math.abs(left - FILM_L) < 0.05,
    ("it stops at the film: %.4f L against %.3f"):format(left, FILM_L)
)

-- No further, ever. Two thousand ticks later the grating is standing in
-- the same three and a bit litres, because what is under the film has
-- no excess and a drain may not take it -- a tile pulled drier than any
-- neighbour could make it would pull forever.
t.run_ticks(2000)
assert(
    litres(1) > FILM_L * 0.95,
    ("the film is still there: %.4f L"):format(litres(1))
)
assert(
    math.abs(t.matter_totals().substances.water - POURED) < 1e-6,
    ("and every mole is accounted for: %.6f vs %.6f mol")
        :format(t.matter_totals().substances.water, POURED)
)

-- Accounted for WHERE. The books balance because the drain's register
-- is inside them, and there are three registers a mole can leave the
-- deck into: what went out through a hull breach (`vented`), what the
-- settling sweep took off a tile the engine had a rounding opinion
-- about (`t.nullified`), and what a grating swallowed (`t.drained`).
-- A pass that booked this flood into either of the others would balance
-- exactly as well, so the spec names the one it means.
--
-- 6.683 L over the film, at 55.51 mol/L, is 371 mol.
local EXPECTED_DRAINED = (10.0 - FILM_L) * 55.51
local swallowed = t.drained().water or 0
assert(
    math.abs(swallowed - EXPECTED_DRAINED) < 0.01 * EXPECTED_DRAINED,
    ("the grating swallowed it: %.4f mol against %.4f"):format(swallowed, EXPECTED_DRAINED)
)
assert(
    (t.nullified().water or 0) < 1e-9,
    ("and no sweep took any of it: %.9f mol"):format(t.nullified().water or 0)
)

-- ---------------------------------------------------------------
-- IT DOES NOT REACH PAST ITS OWN TILE.
--
-- The grating in the middle of a three-tile corridor, ten litres on the
-- east tile, nothing on the west one. The spill levels toward the
-- grating and goes down it, and the drain holds its own tile AT the
-- film the whole time -- so there is never any excess on it to push
-- west, and the dry tile stays dry.
--
-- That is the difference between a drain and a pump: this one takes
-- what arrives, and nothing about it reaches for what has not.
-- ---------------------------------------------------------------
t.world([==[(
    name: "a grating in a corridor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    structures: [(2, 1, "floor_drain")],]==] .. SPILL .. [==[
    painted: [(3, 1, "spill_10l")],
)]==], 0)

t.join()
t.tick()

local CORRIDOR_POURED = t.matter_totals().substances.water
assert(litres(1) < 1e-6, "the west tile starts dry")
assert(litres(2) < 1e-6, "and so does the grating")

for _ = 1, 8 do
    t.run_ticks(200)
    -- Checked every step rather than once at the end: a drain that
    -- overshot its tile for one pass and refilled it would be invisible
    -- to a single reading at the finish.
    assert(
        litres(2) <= FILM_L * 1.01,
        ("the grating never stands deeper than the film: %.4f L"):format(litres(2))
    )
    assert(litres(1) < 1e-6, ("and the west tile stays dry: %.6f L"):format(litres(1)))
end

assert(litres(2) > FILM_L * 0.95, ("the grating is damp, not dry: %.4f L"):format(litres(2)))
assert(litres(3) < 6.0, ("the spill went down it: %.4f L"):format(litres(3)))
assert(
    math.abs(t.matter_totals().substances.water - CORRIDOR_POURED) < 1e-6,
    ("with the books still balanced: %.6f vs %.6f mol")
        :format(t.matter_totals().substances.water, CORRIDOR_POURED)
)
