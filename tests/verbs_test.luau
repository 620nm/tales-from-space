-- SIX WORDS FOR ONE TRANSFER, and the six rows they leave behind.
--
-- Every gesture below moves matter through the same primitive
-- (`Sim::move_matter`, sim/owner/ops.rs). What differs is the WORD the
-- content file used -- `sim.matter.pour`, `.drink`, `.spill`, `.fill`,
-- `.inject`, or the generic `.transfer` -- and each word carries its
-- own phases, its own overflow policy, its own extra reach and its own
-- row (docs/LUAU-API.md 8.2).
--
-- The row is what this spec is about, because the row is the half a
-- player never sees and an admin lives in. A swig and a needleful both
-- end in a bloodstream; charging a bottle off a canister and tipping a
-- beaker into it are both vessel to vessel. Inferring the row from the
-- pair of owners could not tell either apart. Naming the verb can, and
-- these six rows are that claim in one bench.
t.world([==[(
    name: "verb bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(1, 1), (5, 1)],
    items: [
        (1, 1, "beaker_libital"),
        (2, 1, "beaker"),
        (3, 1, "bottle"),
        (4, 1, "syringe"),
        (4, 1, "beaker_libital"),
    ],
    structures: [(3, 2, "canister")],
)]==], 0)

local medic = t.join()
local patient = t.join()
t.run_ticks(3)

local full = t.target_at(1, 1, "beaker_libital")
local empty = t.target_at(2, 1, "beaker")
local jar = t.target_at(3, 1, "bottle")
local syringe = t.target_at(4, 1, "syringe")
local dose = t.target_at(4, 1, "beaker_libital")
local pid = t.body_id(patient)

local function take(p, x, y, id)
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.tick()
    end
    t.click(p, x, y, id)
    t.run_ticks(2)
end
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(3)
end
local function rows(kind)
    return #t.ledger_rows(kind)
end

-- ---- pour: vessel to vessel ------------------------------------------
take(medic, 1, 1, full)
t.click(medic, 2, 1, empty)
t.run_ticks(2)
assert(rows("poured") == 1, ("one pour, got %d"):format(rows("poured")))

-- ---- drink: vessel to the bloodstream of whoever holds it ------------
-- A click on your own tile with a beaker in hand. The word is `drink`
-- and not `transfer`, so the vessel has to be in the DRINKER's own
-- hands -- which it is, because they are holding it.
t.click(medic, 1, 1)
t.run_ticks(2)
assert(rows("drank") == 1, ("one swig, got %d"):format(rows("drank")))

-- ---- spill: vessel to the deck ---------------------------------------
t.click(medic, 1, 2)
t.run_ticks(2)
assert(rows("spilled") == 1, ("one spill, got %d"):format(rows("spilled")))
local puddle = t.ledger_rows("spilled")[1]
assert(puddle.at[1] == 1 and puddle.at[2] == 2, "on the tile it was tipped onto")

-- ---- fill: a line into a vessel, gas only ----------------------------
-- Charging a bottle off a canister is vessel to vessel exactly as a
-- pour is, and it is NOT a pour: it moves the gas phase and it lands a
-- `filled` row, because "who took this out of the loop" is a question
-- worth being able to ask of a shift log.
local can = t.target_at(3, 2)
assert(can ~= nil, "a canister stands on the deck")
assert(t.charge_vessel(3, 2, "o2", 2000.0), "the canister takes a charge")
t.tick()
walk(medic, "east")
walk(medic, "east")
take(medic, 3, 1, jar)
assert(t.hands(medic).held == "bottle", "the bottle is in hand")
t.click(medic, 3, 2, can)
t.run_ticks(2)
assert(rows("filled") == 1, ("one charge, got %d"):format(rows("filled")))
assert(rows("poured") == 1, "and it did not pass itself off as a pour")

-- ---- transfer: the generic, for a gesture with no word ---------------
-- A syringe SUCKS. That is not one of the five gestures and the file
-- does not pretend it is: the draw is `sim.matter.transfer`, and the
-- ledger says `matter_moved`.
walk(medic, "east")
take(medic, 4, 1, syringe)
assert(t.hands(medic).held == "syringe", "the syringe is in hand")
t.click(medic, 4, 1, dose)
t.run_ticks(2)
assert(rows("matter_moved") == 1, ("one draw, got %d"):format(rows("matter_moved")))
assert(rows("poured") == 1, "a draw is not a pour")
assert(rows("drank") == 1, "and it is not a drink either")

-- ---- inject: through a needle, into a bloodstream --------------------
-- The far end is the same bloodstream a swig reaches, and the row is
-- not `drank`. It also needs the thing it goes through to declare a
-- sharpness -- the syringe does (items/syringe.luau); a beaker does
-- not, which is why a beaker cannot be spelled this way at all.
t.use_self(medic)
t.run_ticks(2)
t.click(medic, 5, 1, pid)
t.run_ticks(2)
assert(rows("injected") == 0, "the needle parks before it lands")
t.run_ticks(62) -- tg's CHEM_INTERACT_DELAY, three seconds
assert(rows("injected") == 1, ("one injection, got %d"):format(rows("injected")))
assert(rows("drank") == 1, "a needle is not a mouthful")

-- Six gestures, six rows, and every one of them named by the word the
-- content file used rather than guessed from the pair of owners.
assert(rows("poured") == 1 and rows("drank") == 1 and rows("spilled") == 1)
assert(rows("filled") == 1 and rows("matter_moved") == 1 and rows("injected") == 1)
