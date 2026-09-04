-- The flooded alcove on Outpost Zero.
--
-- A map paints a tile with a Matter Blend and the tile opens the shift
-- holding it (docs/map-properties/blends.md). Nothing says a blend has
-- to be a gas, so this one is water: a litre of it thinning back into
-- the alcove and fifty litres standing at the airlock door.
--
-- What a crewman can actually tell is the LOOK at the deck, which is
-- the only place the ladder of puddle pictures is player-visible: a
-- bare tile with a puddle on it says so and names the amount, and a dry
-- tile beside it says nothing (sim/examine.rs, gated at the same
-- threshold the floor layer draws at, so a look never reports a film
-- the eye cannot find).
--
-- The tiers above this one -- the two river tiles a deep pool wears --
-- are proven where they live, by the asset gate walking every sprite a
-- profile names (content/matter_appearances.luau, tools/check.sh
-- lint-assets).

t.world_file("outpost.ron", 7)
local p = t.join()
t.tick()

local DEEP = { 11, 8 }
local SHALLOW = { 13, 7 }
local DRY = { 14, 7 }

local function look_at(xy)
    local seen = t.examine(p, xy[1], xy[2])
    assert(seen ~= nil, ("(%d,%d) is not in sight"):format(xy[1], xy[2]))
    return table.concat(seen.lines, "\n")
end

-- ---------------------------------------------------------------
-- Fifty litres at the door, and a litre three tiles back. The line
-- names the phase, because a puddle and a lump of ice on the same
-- deck are two different things to step in -- and it leads with the
-- volume, because a depth is what a crewman is deciding about.
-- ---------------------------------------------------------------
assert(look_at(DEEP) == "A puddle: 50.00 L · 2775.50 mol of liquid water.",
    "the deep end reads as fifty litres: " .. look_at(DEEP))
assert(look_at(SHALLOW) == "A puddle: 1.00 L · 55.51 mol of liquid water.",
    "and the shallow end as one: " .. look_at(SHALLOW))

-- ---------------------------------------------------------------
-- The dry tile beside it says nothing at all. The threshold is the
-- picture's own, so there is no such thing as a puddle a look
-- reports and the deck does not draw.
-- ---------------------------------------------------------------
assert(look_at(DRY) == "", "a dry deck is a deck: " .. look_at(DRY))

-- ---------------------------------------------------------------
-- And the water is REAL, not a decal: fifty litres out of a cubic
-- metre is five percent of the tile the air had, so the air over
-- the deep end reads higher than the air over a dry one. A picture
-- would not do that.
-- ---------------------------------------------------------------
local deep_kpa = t.room_pressure(DEEP[1], DEEP[2])
local dry_kpa = t.room_pressure(DRY[1], DRY[2])
assert(deep_kpa > dry_kpa + 1.0,
    ("the slug displaces the air over it: %.2f vs %.2f"):format(deep_kpa, dry_kpa))

-- ---------------------------------------------------------------
-- THE SILL IS WHAT HOLDS IT.
--
-- A liquid levels now (docs/matter-world/flow.md): five centimetres of
-- standing water is fifteen times the film water stops thinning at, so
-- the only reason this pool is still a pool half a minute into the
-- shift is that it has nowhere to go. The deep pair is a compartment --
-- walls at (12,7) and (13,8), the glazed leaf at (11,7) above it, the
-- exterior airlock at (11,9) below it -- and both leaves are shut. A
-- closed door seals its cell's links exactly as the wall beside it
-- does, for water as for air.
--
-- The litre tiles in the alcove need no sill: a litre over a square
-- metre is a millimetre deep, under the film, and a puddle under the
-- film has no excess for a link to take.
-- ---------------------------------------------------------------
t.run_ticks(600)
local still = look_at(DEEP)
local litres = tonumber(string.match(still, "A puddle: ([%d%.]+) L"))
assert(litres ~= nil, "the pool is still a pool: " .. still)
assert(litres > 50.0 * 0.99, "and still fifty litres of one: " .. still)
assert(look_at(DRY) == "", "and it never reached the tile beside it")

-- ---------------------------------------------------------------
-- OPEN THE LEAF AND IT IS EVERYBODY'S PROBLEM.
--
-- Somebody walks down to the alcove and opens the glazed sill. The
-- breaker goes the moment the leaf is clear, because an unpowered door
-- has no motors to close itself with (tests/crowbar_test.luau) -- what
-- is being watched is water through a doorway, not the autoclose
-- timer.
--
-- A hundred litres then finds every tile the middle of the station can
-- reach it from. The claim is the COLLAPSE of the picture the shift
-- opened with: a fifty-to-one difference between the deep end and the
-- alcove becomes a difference of a few percent, and the tile that was
-- dry is standing in water deeper than the film.
-- ---------------------------------------------------------------
local function standing(xy)
    local liquid = t.room_liquid(xy[1], xy[2])
    return (liquid and liquid.water) or 0
end

local DEEP_TOO = { 12, 8 }
local FILM_L = 3.32 -- water on painted deck: 2*sqrt(sigma/rho g)*sin(theta/2)
local WATER_START = t.matter_totals().substances.water

local before = standing(DEEP) / standing(SHALLOW)
assert(before > 45.0, ("the alcove opens fifty to one: %.1f"):format(before))

for _ = 1, 3 do
    t.move(p, "south")
    t.run_ticks(6)
end
local x, y = t.pos(p)
assert(x == 11 and y == 6, ("at the sill, got (%d,%d)"):format(x, y))
t.click(p, 11, 7, t.target_at(11, 7))
t.run_ticks(15)
assert(t.door_at(11, 7).open, "the glazed sill is open")
t.outage()
t.run_ticks(5)
assert(t.door_at(11, 7).open, "and a dead leaf stays where it was left")

t.run_ticks(10000)

-- The pair drained: an eightfold drop, and the two tiles of it are
-- still level with each other.
assert(standing(DEEP) < 6.0, ("the deep end let go: %.4f L"):format(standing(DEEP)))
assert(
    math.abs(standing(DEEP) - standing(DEEP_TOO)) <= 0.05 * standing(DEEP),
    ("the pair is level: %.4f and %.4f L"):format(standing(DEEP), standing(DEEP_TOO))
)

-- And the alcove came up to meet it. Not to the same number: each link
-- stops when its flux falls under the millilitre quantum, and a chain
-- of two dozen of them leaves a shallow gradient behind
-- (docs/matter-world/flow.md, "The residual"). Fifty to one is what
-- collapsed.
local after = standing(DEEP) / standing(SHALLOW)
assert(after < 1.2, ("the alcove came level with the door: %.3f"):format(after))
assert(standing(SHALLOW) > 4.0, ("the shallow end is deep now: %.4f L"):format(standing(SHALLOW)))
assert(standing(DRY) > FILM_L, ("and the dry tile is standing water: %.4f L"):format(standing(DRY)))

-- Every mole of it is the same water. A flood that conserves nothing
-- is a decal with extra steps.
assert(
    math.abs(t.matter_totals().substances.water - WATER_START) < 1e-6,
    ("the flood made and lost nothing: %.6f vs %.6f mol")
        :format(t.matter_totals().substances.water, WATER_START)
)
