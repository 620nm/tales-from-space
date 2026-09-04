-- A puddle levels, and a shut door is a sill.
--
-- Water on a deck spreads by gravity at a rate viscosity sets, and
-- stops when every tile it can reach stands at the same depth
-- (docs/matter-world/flow.md). What it CANNOT cross is a sealed link,
-- and a closed airlock is one: the leaf holds a flood the way the wall
-- beside it does, until somebody opens it and the same water goes
-- through. The third claim is the floor under all of it -- surface
-- tension leaves a film about 3.3 mm of water deep, so a spill thinner
-- than that has no excess to give and stays exactly where it landed.
--
-- The corridor is five tiles with an airlock on the fourth. Nothing
-- here is powered, which is the point twice over: a dark leaf is shut
-- to begin with, and once pried it has no motors to close itself again
-- (tests/crowbar_test.luau), so the flood is watched rather than the
-- autoclose timer.

local FILM_L = 3.32 -- 2*sqrt(sigma/rho g)*sin(theta/2), water on painted deck

-- 60 L of water, which is 3330.6 mol: 55.51 mol is a litre of it, and
-- sixty of those over a square metre of deck is six centimetres deep --
-- eighteen films, so there is excess to move for as long as it takes to
-- level five tiles. The two air rows ride along because a `total` blend
-- IS the tile's whole contents: water on its own would open the
-- corridor airless. They are ordinary 21/79 at 20 C over a cubic metre
-- (41.573 mol = 101.325 kPa), the arithmetic
-- content/blends/standard_air.luau spells out.
local CORRIDOR = [==[(
    name: "spill corridor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        '+': (turf: Floor, fixture: Some(Door)),
    },
    rows: [
        "#######",
        "#...+.#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "crowbar")],
    blends: {
        "spill_60l": (rows: [("water", 3330.6), ("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: total),
    },
    painted: [(1, 1, "spill_60l")],
)]==]

t.world(CORRIDOR, 0)

local p = t.join()
t.tick()

local function litres(x)
    local standing = t.room_liquid(x, 1)
    return (standing and standing.water) or 0
end

local function dry(x, why)
    local standing = t.room_liquid(x, 1)
    local held = (standing and standing.water) or 0
    assert(held < 1e-6, ("%s: (%d,1) holds %g L"):format(why, x, held))
end

-- Equal to within five percent of the deeper of the two. The spec
-- never names the depth: what the law promises is a level, and the
-- level a corridor settles at is arithmetic on what was poured.
local function level(a, b, why)
    local ha, hb = litres(a), litres(b)
    local deeper = math.max(ha, hb)
    assert(deeper > 1.0, ("%s: (%d,1) and (%d,1) are both dry"):format(why, a, b))
    assert(
        math.abs(ha - hb) <= 0.05 * deeper,
        ("%s: (%d,1) reads %.4f L and (%d,1) reads %.4f L"):format(why, a, ha, b, hb)
    )
end

local function water_everywhere()
    return t.matter_totals().substances.water
end

local POURED = water_everywhere()
assert(math.abs(POURED - 3330.6) < 1e-6, ("the blend is what was painted: %.4f mol"):format(POURED))
assert(litres(1) > 59.9, ("and it is standing on one tile: %.4f L"):format(litres(1)))

-- ---------------------------------------------------------------
-- IT SPREADS FROM WHERE IT FELL.
--
-- Twenty ticks in, the tile it landed on is still the deepest, the
-- one beside it is shallower, and the third has not been reached.
-- A puddle crosses tiles; it does not appear in a room.
-- ---------------------------------------------------------------
t.run_ticks(20)
assert(litres(1) > litres(2), ("the source is deeper: %.4f vs %.4f"):format(litres(1), litres(2)))
assert(litres(2) > litres(3), ("and the frontier shallower still: %.4f vs %.4f"):format(litres(2), litres(3)))
dry(4, "the shut leaf has not been crossed")

-- ---------------------------------------------------------------
-- AND THEN IT IS LEVEL, AND THE DOOR IS A WALL.
--
-- Three tiles, one depth, in a hundred ticks. The fourth tile is the
-- one under the leaf -- its own sealed pocket while the door is shut,
-- exactly as a gas cannot reach it (tests/diffusion_test.luau) -- and
-- the fifth is behind it.
-- ---------------------------------------------------------------
t.run_ticks(80)
level(1, 2, "the corridor levelled")
level(2, 3, "the corridor levelled")
assert(litres(1) > 3.0 * FILM_L, ("and it is deep water: %.4f L"):format(litres(1)))
dry(4, "a shut door is a sill")
dry(5, "and nothing got past it")

-- Every mole is still on the books. Some of the puddle is vapour by
-- now -- a wet deck dries into the room over it (tests/spill_test.luau)
-- -- so the reading that has to hold is the whole of the water, not the
-- part of it that is still liquid.
assert(
    math.abs(water_everywhere() - POURED) < 1e-6,
    ("nothing was made or lost: %.6f vs %.6f mol"):format(water_everywhere(), POURED)
)
assert(litres(1) + litres(2) + litres(3) < 60.1, "and no tile invented any")

-- ---------------------------------------------------------------
-- OPEN IT, AND THE SAME WATER GOES THROUGH.
--
-- A crowbar on a dark leaf: sixty ticks of prying, and then it stays
-- open. Two hundred ticks later the flood has found the two tiles it
-- could not reach and all five stand at one depth -- twelve litres
-- apiece, because sixty litres over five tiles is what levelling MEANS.
-- ---------------------------------------------------------------
t.click(p, 2, 1, t.target_at(2, 1, "crowbar"))
t.tick()
assert(t.hands(p).held == "crowbar", "the crowbar is in hand")
t.move(p, "east")
t.run_ticks(4)
t.move(p, "east")
t.run_ticks(4)
assert(not t.door_at(4, 1).powered, "the leaf is dark, so it will not shut itself again")
t.click(p, 4, 1, t.target_at(4, 1))
t.run_ticks(80)
assert(t.door_at(4, 1).open, "pried open")

t.run_ticks(200)
level(1, 2, "the whole corridor levelled")
level(2, 3, "the whole corridor levelled")
level(3, 4, "the whole corridor levelled")
level(4, 5, "the whole corridor levelled")
assert(litres(5) > FILM_L, ("the far end is a puddle, not a film: %.4f L"):format(litres(5)))
assert(
    math.abs(water_everywhere() - POURED) < 1e-6,
    ("and still every mole: %.6f vs %.6f mol"):format(water_everywhere(), POURED)
)

-- ---------------------------------------------------------------
-- UNDER THE FILM THERE IS NO EXCESS.
--
-- The other end of the same law. Three litres over a square metre of
-- deck is 3.0 mm, and water on painted steel stops thinning at 3.3 mm,
-- so a puddle that size is ALREADY the film: it has no excess, no link
-- can take any of it, and two hundred ticks later it is exactly where
-- it was painted while the corridor beside it stays dry. The flood
-- above moved a tile in twenty.
--
-- The beaker tipped beside it is the same claim in a player's hands.
-- 0.60 mol of water is 10.8 mL -- a hundredth of a millimetre, three
-- hundred films thinner -- and what takes it off the deck is not a
-- neighbouring tile but the air over it (tests/spill_test.luau).
-- ---------------------------------------------------------------
t.world([==[(
    name: "under the film",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#######",
        "#.....#",
        "#######",
    ],
    spawns: [(3, 1)],
    items: [(3, 1, "beaker.water")],
    blends: {
        "film_3l": (rows: [("water", 166.53), ("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: total),
    },
    painted: [(1, 1, "film_3l")],
)]==], 0)

local q = t.join()
t.tick()

local beaker = t.target_at(3, 1, "beaker.water")
t.click(q, 3, 1, beaker) -- pick it up
t.tick()
t.click(q, 4, 1) -- and tip it onto the deck beside us
t.tick()

local painted = litres(1)
assert(painted > 2.95 and painted < FILM_L, ("three litres is under the film: %.4f L"):format(painted))
local tipped = litres(4)
assert(tipped > 0.010 and tipped < 0.011, ("and 10.8 mL is on the deck: %.6f L"):format(tipped))

local WATER_START = water_everywhere()
t.run_ticks(200)

assert(litres(1) > 2.9, ("the film stayed where it was painted: %.4f L"):format(litres(1)))
dry(2, "and its neighbour was never wet")
dry(3, "nor the tile past that")
dry(5, "nor the far side of the tipped beaker")
assert(
    math.abs(water_everywhere() - WATER_START) < 1e-6,
    ("every mole accounted for: %.6f vs %.6f"):format(water_everywhere(), WATER_START)
)

-- What left the deck went up, not sideways: the air over the tile the
-- beaker was tipped onto is carrying it.
local vapour = t.room_gas(4, 1).water
assert(vapour ~= nil and vapour > 1e-3, "the tipped beaker dried into the room")
