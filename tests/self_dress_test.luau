-- Taking your own clothes off, and putting them back on.
--
-- There is no wardrobe panel for your own body: tg refuses the
-- mouse-drop on yourself outright (code/datums/elements/strippable.dm:41)
-- and so does this engine, because dressing yourself is the DIRECT
-- path and always was -- the equip gesture, and the click on the slot
-- you want filled.  tests/strip_test.luau is the other body's story;
-- this one is the loop a crewman does to himself twenty times a shift.
--
-- The bug it pins: the garment ends up in the OFF hand -- which is
-- where it lands the moment you pick anything else up, or swap hands
-- to open a door -- and every way of putting it back on silently did
-- nothing.  Nothing happened and nothing was said, which reads from
-- inside the suit as "I can take it off but I cannot put it on".

local ARENA = [==[(
    name: "locker room",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1)],
    items: [ (1, 1, "eva_suit") ],
)]==]

t.world(ARENA, 0)
local crewman = t.join()
t.run_ticks(3)

local function said(needle)
    return (" " .. table.concat(t.messages(crewman), " || ") .. " "):find(needle, 1, true) ~= nil
end

-- ---- on, off, on again, with the active hand ---------------------------
t.click(crewman, 1, 1, t.target_at(1, 1, "eva_suit"))
t.run_ticks(2)
assert(t.hands(crewman).held == "eva_suit", "picked up")

t.equip(crewman)
t.run_ticks(2)
assert(t.worn(crewman).suit == "eva_suit", "the suit goes on")
assert(t.hands(crewman).held == nil, "and out of the hand")

t.unequip(crewman, "suit")
t.run_ticks(2)
assert(t.worn(crewman).suit == nil, "and comes off again")
assert(t.hands(crewman).held == "eva_suit", "into the hand that took it off")

t.equip(crewman)
t.run_ticks(2)
assert(t.worn(crewman).suit == "eva_suit", "and back on, which always worked")

-- ---- the same loop with the garment in the OTHER hand ------------------
-- A hand swap is not a decision about the suit; it is what you do to
-- open a door.  It must not be what stops you getting dressed.
t.unequip(crewman, "suit")
t.run_ticks(2)
t.swap_hands(crewman)
t.run_ticks(2)
assert(t.hands(crewman).held == nil, "the active hand is the empty one now")

t.equip(crewman)
t.run_ticks(2)
assert(t.worn(crewman).suit == "eva_suit",
    "an empty active hand defers to the hand actually holding the suit")

-- ---- and reaching for nothing says so ---------------------------------
-- A gesture that does nothing in silence cannot be told from one the
-- server refused, which is the whole reason the failure above went
-- looking for a button that was never missing.
t.equip(crewman)
t.run_ticks(2)
assert(said("hands are empty"), "an empty-handed equip is answered")

print("self-dress: the suit goes back on from either hand, and an empty grab says so")
