-- A hook that mints a vessel says what is in it.
--
-- `sim.entity.spawn`'s `initial.contents` is the fill grammar spelled at
-- the script boundary (docs/LUAU-API.md section 6), and the softdrinks
-- machine is the thing in this station that has an honest reason to use
-- it: hand it an empty bottle and it hands you a cold one, filled from
-- its own crate rather than from anything the world was already
-- carrying (content/fixtures/vendor.luau).
--
-- Three claims, all of them things a player could cause:
--
--   1. A variant IS its base to a machine that asks. The bottle of
--      iodine is `bottle.iodine`, a prototype of its own; the machine
--      lists no variants and takes it anyway, because `Handle.base`
--      answers what it was derived from.
--   2. What the hook named is what is in the glass, at the temperature
--      the hook named -- not at room temperature, and not the fill the
--      `bottle` prototype declares (which is none).
--   3. Moles that appeared from nowhere are on the record, attributed
--      to the machine's own script and to the crewman who asked.
t.world([==[(
    name: "canteen",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "######",
        "#o...#",
        "#a..g#",
        "######",
    ],
    spawns: [(2, 2)],
    machines: [(2, 1, "vendor")],
    items: [(2, 2, "bottle.iodine")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3),
    ],
)]==], 0)

local p = t.join()
t.run_seconds(1)

local function said(needle)
    return table.concat(t.messages(p), "\n"):find(needle, 1, true) ~= nil
end

-- ---------------------------------------------------------------
-- ONE: A VARIANT IS A BOTTLE.
--
-- The machine's script asks `item.base`, so a labelled preconfiguration
-- it has never heard of routes into the bottle branch. It gets the
-- machine's own refusal -- "only takes empties" -- which is the proof:
-- a thing the machine did not recognise as a bottle would have been an
-- ordinary swing and said nothing at all.
-- ---------------------------------------------------------------
local bottle = t.target_at(2, 2, "bottle.iodine")
assert(bottle ~= nil, "the map placed the labelled bottle")
t.click(p, 2, 2, bottle) -- pick it up
t.run_ticks(2)
assert(t.hands(p).held == "bottle.iodine", "the bottle is in the working hand")

local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1)) -- swing it at the machine
t.run_ticks(2)
assert(said("only takes empties"),
    "the machine knows a bottle when it sees one, and this one is full")
assert(t.hands(p).held == "bottle.iodine", "and it is still in your hand")

-- ---------------------------------------------------------------
-- TWO: THE EMPTY GOES IN, A COLD ONE COMES OUT.
--
-- Tip the crystals onto the deck and the same bottle is an empty. Now
-- the machine takes it and mints its own product: what its file names,
-- at the temperature its chiller runs at, in a plain `bottle` that
-- declares no fill of its own.
-- ---------------------------------------------------------------
t.click(p, 3, 2) -- the deck beside you: a spill
t.run_ticks(4)
assert(t.vessel(bottle).moles < 1e-6, "the bottle is an empty now")

local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1))
t.run_ticks(2)
assert(said("cold bottle of water"), "the machine served one")
assert(t.hands(p).held == nil, "and swallowed the empty you handed over")

local served = t.target_at(2, 1, "bottle")
assert(served ~= nil, "a plain bottle is standing at the machine's feet")
local reading = t.vessel(served)
assert(reading ~= nil, "and it is a vessel")
assert(math.abs(reading.moles - 2.5) < 1e-6,
    "holding the machine's own measure: " .. reading.moles)
assert((reading.contents.water.liquid or 0) > 2.4,
    "and it is water, in the liquid it is at this temperature")
assert(reading.temp_k < 285.0,
    "cold, the way a chiller leaves it -- not room temperature: " .. reading.temp_k)
assert(reading.temp_k > 270.0,
    "cold, not frozen: " .. reading.temp_k)

-- ---------------------------------------------------------------
-- THREE: THE BOOKS SAY WHERE IT CAME FROM.
--
-- A vended drink is matter that did not exist a moment ago, and the one
-- thing an audit cannot reconstruct is a mole with no row behind it.
-- The row names the machine's script and the crewman who asked for it.
-- ---------------------------------------------------------------
local mints = t.ledger_rows("minted")
assert(#mints == 1, "one charge was named, one row: " .. #mints)
assert(mints[1].substance == "water", "and it names what appeared: " .. mints[1].substance)
assert(math.abs(mints[1].moles - 2.5) < 1e-6,
    "and how much: " .. mints[1].moles)
assert(mints[1].actor.kind == "script", "the machine's own file did it")
assert(mints[1].actor.triggered_by, "at the request of the crewman standing there")
