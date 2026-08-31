-- The sprayer's ranged claim, refused. Sight, range, line, the active
-- hand and the click window are native facts (the engine's
-- sim/interact/click.rs and sim/spray.rs); this file proves the two a
-- player can make happen with their feet and their hands -- a click
-- past the bottle's range, and a click with the bottle in the wrong
-- hand -- and one thing the parcel does on the way: a puff aimed into
-- a wall doses the open tile before it and ends at the wall's face,
-- with the share that had nowhere to land on the record and off the
-- books, exactly as the record says.
t.world([==[(
    name: "spray hall",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "############",
        "#..........#",
        "#..........#",
        "############",
    ],
    spawns: [(2, 1)],
    items: [
        (3, 1, "spray_bottle"),
        (1, 1, "water_bottle_large"),
    ],
)]==], 19)

local p = t.join()
t.tick()

-- The default is 1e-8; a caller may ask for more. Only the draw figures
-- need it: a bottle standing open in a room trades a little vapour with
-- the air over it, and how much depends on how fast that air moves, so
-- the parcel a draw lands on is exact to about a part in a million
-- rather than to the last bit.
local function near(got, want, what, slack)
    assert(math.abs(got - want) < (slack or 1e-8),
        ("%s: wanted %g, got %g"):format(what, want, got))
end

-- Charge the sprayer the way a janitor does: uncap the bottle, set it
-- down beside the sprayer, pick the sprayer up and draw from the
-- bottle at arm's length (chemical_containers_test.luau has the
-- capped-source refusal).
local reservoir = t.target_at(1, 1, "water_bottle_large")
t.click(p, 1, 1, reservoir)
t.tick()
t.use_self(p)
t.tick()
t.move(p, "east")
t.tick()
t.drop(p)
t.tick()
t.move(p, "west")
t.tick()
local spray = t.target_at(3, 1, "spray_bottle")
t.click(p, 3, 1, spray)
t.tick()
t.click(p, 3, 1, reservoir)
t.tick()
near(t.contents(spray).water, 1.25, "the sprayer holds 50 u")
assert(t.hands(p).held == "spray_bottle", "and it is in the active hand")

-- OUT OF RANGE. Six tiles is inside what the crewman can see and one
-- past the bottle's declared five: the click is refused before any
-- handler runs, so nothing is drawn and nothing is heard.
t.click(p, 8, 1)
t.tick()
assert(#t.sounds(p) == 0, "a click past the range is silent")
assert(#t.ledger_rows("MatterSprayed") == 0, "and launches nothing")
near(t.contents(spray).water, 1.25, "and draws nothing")

-- THE WRONG HAND. The sprayer is still held, in the hand that is not
-- active; a ranged claim is the ACTIVE hand's, and an empty one claims
-- nothing.
t.swap_hands(p)
t.tick()
assert(t.hands(p).held == nil, "the active hand is empty")
t.click(p, 5, 1)
t.tick()
assert(#t.sounds(p) == 0, "the off hand makes no ranged claim")
assert(#t.ledger_rows("MatterSprayed") == 0, "and launches nothing")
t.swap_hands(p)
t.tick()

-- ...and the same click with the bottle back in the active hand.
t.click(p, 5, 1)
t.tick()
local launched = t.sounds(p)
assert(#launched == 1 and launched[1] == "spray", "an accepted launch is heard once")
assert(#t.ledger_rows("MatterSprayed") == 1, "and is on the record")
t.run_ticks(20)
near(t.contents(spray).water, 1.125, "one launch draws a 5 u parcel", 1e-5)
assert(#t.ledger_rows("ParcelLost") == 0,
    "three open tiles take three shares: nothing was lost")

-- INTO THE WALL. Two tiles west is the hull. The puff doses the open
-- tile in between and ends where its move fails; the share it was
-- carrying for the wall's tile is lost, and the record says so: one
-- row, caused by the launch, for exactly the moles the world is short.
local before = t.matter_totals()
t.click(p, 0, 1)
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 2, "aimed at a wall still launches")
t.run_ticks(20)
local lost = t.ledger_rows("ParcelLost")
assert(#lost == 1, "one row for what never landed, not one per tile")
assert(lost[1].why == "blocked", "and it says why: " .. tostring(lost[1].why))
near(lost[1].moles, 0.125 / 2, "half the parcel: one share of two")
assert(lost[1].cause ~= nil, "caused by the launch")
local after = t.matter_totals()
near(before.moles - after.moles, lost[1].moles,
    "what the world is short is what the record says left it")
