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
-- It does not go anywhere, either. A liquid on a tile does not
-- level, drain or spread -- the engine marks that gap for itself
-- rather than pretending it is closed -- so half a minute into the
-- shift the pool is where somebody left it, minus the mole or so
-- that went into the air over it, and the dry tile is still dry.
--
-- What holds it once it CAN move is the sill: the deep pair is a
-- compartment with a glazed leaf on one side and the exterior airlock
-- on the other, and both are shut (maps/outpost.ron).
-- ---------------------------------------------------------------
t.run_ticks(600)
local still = look_at(DEEP)
local litres = tonumber(string.match(still, "A puddle: ([%d%.]+) L"))
assert(litres ~= nil, "the pool is still a pool: " .. still)
assert(litres > 50.0 * 0.99, "and still fifty litres of one: " .. still)
assert(look_at(DRY) == "", "and it never reached the tile beside it")
