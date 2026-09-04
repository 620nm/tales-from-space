-- Mopping: the one gesture on the station that takes a liquid OFF a
-- deck. Everything else a crewman can do with a puddle puts one there.
--
-- A mop is a vessel and a tile is a body of matter, so this is the pour
-- every vessel already does with the ends swapped: the deck fills the
-- head, the head is wrung out into whatever you point it at. What that
-- buys is the claim below -- the water that leaves the tile ARRIVES in
-- the mop, and the water that leaves the mop arrives in the beaker, and
-- the station is holding the same three litres at the end of it as at
-- the start.
--
-- The stroke is the HEAD, not a dose: what one pass lifts is what a
-- quarter-litre mop can hold, so a flood takes as many strokes as it
-- takes. tg meters its own by time instead (mop.dm:20-22, a fifteen-unit
-- head on a second-and-a-half swing); there is no timed action here to
-- hang that on, so a click is a stroke.
t.world([==[(
    name: "wet deck",
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
    // Three litres standing on one tile: 55.51 mol of water is a litre
    // of it, and the two air rows ride along because a painted tile
    // holds what the blend says and nothing else -- a flooded deck is
    // not a decompressed one.
    blends: {
        "water_3l": (rows: [("water", 166.53), ("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: total),
    },
    painted: [(2, 1, "water_3l")],
    spawns: [(1, 1)],
    items: [
        (1, 1, "mop"),
        (1, 1, "beaker_bluespace"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local mop = t.target_at(1, 1, "mop")
local beaker = t.target_at(1, 1, "beaker_bluespace")

-- A quarter of a litre is the head, which is the whole of what one
-- stroke can lift.
local HEAD_L = 0.25

local function puddle()
    return t.room_liquid(2, 1).water or 0
end

local function held(handle)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents.water or 0
end

-- The last thing the mop said. `t.messages` DRAINS, so a spec asks
-- once and holds the answer.
local function said()
    local lines = t.messages(p)
    return lines[#lines] or ""
end

local water_at_the_start = t.matter_totals().substances.water

assert(math.abs(puddle() - 3.0) < 0.01, ("three litres on the deck, got %g"):format(puddle()))
t.click(p, 1, 1, mop) -- pick it up
t.tick()
assert(held(mop) == 0, "and a dry mop in hand")

-- ---------------------------------------------------------------
-- ONE STROKE, and the puddle is a head lighter. The engine trims the
-- transfer against what is there and what fits, so the deck keeps the
-- rest: a mop is not a drain.
-- ---------------------------------------------------------------
t.click(p, 2, 1)
t.tick()
local stroke = said()
assert(stroke == "You run the mop over the deck.", "the stroke is reported: " .. stroke)
assert(
    math.abs(puddle() - (3.0 - HEAD_L)) < 0.01,
    ("the puddle is a head lighter, got %g L"):format(puddle())
)
local in_the_head = held(mop)
assert(in_the_head > 13.0 and in_the_head < 14.5,
    ("and the head is holding it: %g mol"):format(in_the_head))
assert(t.vessel(mop).headspace_l < 0.01, "with no room left in it")

-- ---------------------------------------------------------------
-- A SECOND STROKE with a full head moves nothing at all, and says so
-- rather than silently doing nothing.
-- ---------------------------------------------------------------
local before = puddle()
t.click(p, 2, 1)
t.tick()
local refusal = said()
assert(refusal == "The mop is soaked through.", "a full mop refuses: " .. refusal)
assert(math.abs(puddle() - before) < 1e-6, "and lifts nothing")
assert(math.abs(held(mop) - in_the_head) < 1e-6, "and takes on nothing")

-- ---------------------------------------------------------------
-- WRINGING IT OUT into the beaker beside you. A wring is not a
-- measured pour: what comes out is the head.
-- ---------------------------------------------------------------
t.click(p, 1, 1, beaker)
t.tick()
local wring = said()
assert(wring == "You wring the mop out.", "the wring is reported: " .. wring)
assert(held(mop) < 1e-6, ("the head is empty, got %g mol"):format(held(mop)))
assert(math.abs(held(beaker) - in_the_head) < 1e-6,
    ("and the beaker has all of it: %g mol"):format(held(beaker)))

-- And an empty mop has nothing to wring, in the words every empty
-- vessel uses.
t.click(p, 1, 1, beaker)
t.tick()
local spent = said()
assert(spent == "The mop is empty.", "a dry mop refuses: " .. spent)

-- A dry deck is a dry deck: the tile the crewman is standing on never
-- had anything on it.
t.click(p, 1, 1)
t.tick()
local dry = said()
assert(dry == "The deck here is dry.", "nothing to take up: " .. dry)

-- ---------------------------------------------------------------
-- AND AGAIN: a wrung-out mop takes another head off the same puddle,
-- which is what makes a flood a chore rather than one click.
-- ---------------------------------------------------------------
t.click(p, 2, 1)
t.tick()
assert(
    math.abs(puddle() - (3.0 - 2 * HEAD_L)) < 0.02,
    ("two strokes, two heads off the deck, got %g L"):format(puddle())
)

-- ---------------------------------------------------------------
-- NOTHING WAS MADE OR LOST doing any of it. The water is in three
-- places now instead of one -- the deck, the head, the beaker, plus
-- whatever went into the air over it -- and it is the same water.
-- ---------------------------------------------------------------
local water_at_the_end = t.matter_totals().substances.water
assert(
    math.abs(water_at_the_end - water_at_the_start) < 1e-6,
    ("the station is holding what it started with: %.6f -> %.6f"):format(
        water_at_the_start, water_at_the_end)
)
