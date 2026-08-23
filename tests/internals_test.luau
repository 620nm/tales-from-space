-- Internals: what a crewman does when the room stops being breathable.
--
-- Three bodies in three sealed cells, each holding a wisp of nitrogen
-- and nothing else -- no oxygen to breathe and far under the pressure
-- a body can stand. They differ only in what they are wearing and
-- whether they opened a valve, and that is the whole spec:
--
--   diver   suit + open tank   nothing happens
--   tanked  open tank only     breathes, and is crushed anyway
--   bare    neither            suffocates AND is crushed
--
-- The middle row is the one worth writing a spec for. A tank feeds
-- LUNGS; it does not pressurize skin, so oxygen out of a bottle in a
-- vacuum buys you the three points of suffocation back and leaves the
-- twenty points of vacuum exactly where they were. Only the suit moves
-- that number, which is tg's division (`calculate_affecting_pressure`,
-- code/modules/mob/living/carbon/human/life.dm:52-73) and the reason
-- the station stocks both.
--
-- A note on the boundary: a tank of pure oxygen at the default 16 kPa
-- release delivers a breath whose oxygen partial pressure is exactly
-- the 16 kPa suffocation threshold -- tg's own calibration -- and the
-- engine promises the boundary breathes (sim/breathing.rs, PP_SLACK).
-- The diver rows below lean on that promise: suited and on internals,
-- a breath of hard vacuum costs nothing, not "very nearly nothing".
t.world([==[(
    name: "the thin cells",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#########",
        "#.#.#.#.#",
        "#########",
    ],
    spawns: [(1, 1), (3, 1), (5, 1)],
    items: [(1, 1, "eva_suit"), (1, 1, "oxygen_tank")],
    room_gas: [(1, 1, "n2", 1.0), (3, 1, "n2", 1.0), (5, 1, "n2", 1.0)],
)]==], 7)

-- One breath cycle, tg's SSmobs × next_breath (8 s at 20 Hz).
local BREATH = 160

local function oxy(p)
    return t.health(p).oxy
end

-- Where in the pack the pocket bottle ended up. Indexed rather than
-- assumed, because a job's kit is a list its own file orders and a spec
-- that hardcodes slot 1 breaks the day somebody reorders it.
local function bottle_row(p)
    for i, id in ipairs(t.stored(p, "back")) do
        if id == "emergency_oxygen" then
            return i
        end
    end
    return nil
end

local function heard(p)
    return " " .. table.concat(t.messages(p), " | ") .. " "
end

local diver = t.join("engineer")
local tanked = t.join("engineer")
local bare = t.join("engineer")
t.run_ticks(2)

-- ---------------------------------------------------------------
-- ONE: EVERYBODY WAKES UP ABLE TO BREATHE.
--
-- Apparatus on the face and a bottle in the pack, on every outfit --
-- tg's survival box (code/game/objects/items/storage/boxes/
-- job_boxes.dm:4-45). The mask is WORN rather than packed, because a
-- job that issues breathing gear in a bag issues it too late.
-- ---------------------------------------------------------------
for _, p in ipairs({ diver, tanked, bare }) do
    assert(t.worn(p).mask == "breath_mask", "the shift starts with apparatus on")
    assert(bottle_row(p) ~= nil, "and a pocket bottle in the pack")
end

-- ---------------------------------------------------------------
-- TWO: THE DIVER GETS DRESSED.
--
-- The suit is on the deck where the map put it, and going outside
-- starts with picking it up. Before the bottle rather than after,
-- because a hand that is already holding something has nowhere to put
-- a space suit -- which is a fact about hands, not about suits.
-- ---------------------------------------------------------------
t.click(diver, 1, 1, t.target_at(1, 1, "eva_suit"))
t.run_ticks(2)
assert(t.hands(diver).held == "eva_suit", "the suit is in hand")
t.equip(diver)
t.run_ticks(2)
assert(t.worn(diver).suit == "eva_suit", "the suit is on")

-- ---------------------------------------------------------------
-- THREE: THE VALVE, AND THE GAUGE THAT COMES WITH IT.
--
-- Out of the pack, into a hand, and the activate-in-hand key. Nothing
-- here reaches past what a player has: a bottle still in the bag
-- cannot be breathed from (tg's `internal.loc != src`), which is why
-- the first gesture is taking it out.
-- ---------------------------------------------------------------
local function open_bottle(p)
    t.take_from(p, "back", bottle_row(p))
    t.run_ticks(2)
    assert(t.hands(p).held == "emergency_oxygen", "the bottle is in hand")
    t.use_self(p)
    t.run_ticks(2)
end

open_bottle(diver)
local supply = t.vitals(diver)
assert(supply ~= nil and supply.tank ~= nil, "the readout lights up on a tank")
assert(
    math.abs(supply.tank - 10 * 101.325) < 1.0,
    "and reads what the file charged it to, ten atmospheres: " .. tostring(supply.tank)
)
-- The panel the tank opens for whoever worked the valve -- tg's own
-- window (`ui_interact`, tanks.dm:234-259), on the gesture that
-- reaches for the tank, which is what a bottle has instead of an
-- examine sheet. Its own spec is tank_window_test.luau; here it is
-- only asked to be THERE, because opening the valve and looking at
-- the bottle are one gesture.
local panel = t.ui(diver)
assert(panel and panel.kind == "held_tank", "the tank reads itself out")

-- ---------------------------------------------------------------
-- FOUR: THE THREE-WAY.
--
-- The second body opens a bottle and wears nothing; the third does
-- neither. Then everybody stands still for five breaths.
-- ---------------------------------------------------------------
open_bottle(tanked)
assert(t.vitals(tanked).tank ~= nil, "the second bottle is open too")

local opening = { diver = oxy(diver), tanked = oxy(tanked), bare = oxy(bare) }
local gauge_0 = t.vitals(diver).tank
-- Four, not more: past this the unprotected pair start dropping, and a
-- body that falls over is a body whose valve the sim shuts for it --
-- which would be a different assertion wearing this one's clothes.
t.run_ticks(BREATH * 4)

assert(
    oxy(bare) > opening.bare + 60.0,
    "nothing at all is suffocation AND vacuum: " .. opening.bare .. " -> " .. oxy(bare)
)
assert(
    oxy(tanked) > opening.tanked + 40.0,
    "a tank alone does not hold the vacuum off the skin -- oxygen in the "
        .. "lungs, and the same crushing: " .. opening.tanked .. " -> " .. oxy(tanked)
)
assert(
    oxy(tanked) < oxy(bare) - 5.0,
    "...though it is still strictly better than nothing, which is the "
        .. "suffocating half it bought back: " .. oxy(tanked) .. " vs " .. oxy(bare)
)
assert(
    oxy(diver) < oxy(tanked) / 5.0,
    "and the suit is the whole of the difference: " .. oxy(diver)
        .. " suited against " .. oxy(tanked) .. " not"
)
assert(
    oxy(diver) <= opening.diver,
    "-- four breaths of hard vacuum for free: "
        .. opening.diver .. " -> " .. oxy(diver)
)

-- ...and the bottle paid for those breaths.
local gauge_1 = t.vitals(diver).tank
assert(
    gauge_1 < gauge_0,
    "the gauge falls as it is breathed: " .. gauge_0 .. " -> " .. gauge_1
)

-- ---------------------------------------------------------------
-- FIVE: LETTING GO SHUTS THE VALVE.
--
-- Not a rule the tank enforces and not one the player has to remember:
-- the sim re-asks "is this still in your hands or on your body" every
-- tick, and a bottle on the deck fails it. Dropping is one half of
-- that sweep; taking the apparatus off is the other, in SEVEN.
-- ---------------------------------------------------------------
t.drop(diver)
t.run_ticks(2)
assert(t.vitals(diver).tank == nil, "the readout goes dark within a tick of letting go")

-- ---------------------------------------------------------------
-- SIX: THE BIG BOTTLE.
--
-- The one the station keeps by the airlock rather than in a pocket:
-- seventy litres at six atmospheres (tg tank_types.dm:26-38), which is
-- the same valve and twenty-odd times the air. Picked up off the deck
-- and opened exactly like the small one, because a tank is a tank.
-- ---------------------------------------------------------------
t.click(diver, 1, 1, t.target_at(1, 1, "oxygen_tank"))
t.run_ticks(2)
assert(t.hands(diver).held == "oxygen_tank", "the big bottle is in hand")
t.use_self(diver)
t.run_ticks(2)
local big = t.vitals(diver).tank
assert(big ~= nil, "and it opens like any other tank")
assert(
    math.abs(big - 6 * 101.325) < 1.0,
    "reading the six atmospheres its file charged it to: " .. tostring(big)
)

-- The suit is still on and the valve is open again, so the last five
-- breaths cost this body nothing either -- which is the pairing the EVA
-- vestibule stocks, spelled out.
local settled = oxy(diver)
t.run_ticks(BREATH * 4)
assert(
    oxy(diver) <= settled,
    "suit and bottle together are a shift outside: " .. settled .. " -> " .. oxy(diver)
)
assert(
    t.vitals(diver).tank < big,
    "and the big gauge falls as the small one did: " .. big .. " -> "
        .. tostring(t.vitals(diver).tank)
)

-- ---------------------------------------------------------------
-- SEVEN: SO DOES TAKING THE APPARATUS OFF.
--
-- The other half of the sweep FIVE started: the valve needs a face it
-- can feed, and a mask in a hand is not on a face. Same rule as tg's
-- cutoff (code/modules/mob/living/carbon/inventory.dm:330-334), asked
-- fresh every tick rather than remembered.
-- ---------------------------------------------------------------
assert(t.vitals(diver).tank ~= nil, "the big bottle is still open")
t.unequip(diver, "mask")
t.run_ticks(2)
assert(t.worn(diver).mask == nil, "the apparatus is off")
assert(t.vitals(diver).tank == nil, "and the valve shut the moment it was")

-- ---------------------------------------------------------------
-- EIGHT: AND BARE-FACED, THE VALVE REFUSES TO OPEN AT ALL.
--
-- The mask is in the off hand, which is exactly not enough: worn or it
-- does not count. Put back on, the same gesture opens the same tank --
-- the refusal is about the face, never about the bottle.
-- ---------------------------------------------------------------
t.use_self(diver)
t.run_ticks(2)
assert(t.vitals(diver).tank == nil, "no apparatus, no internals")

t.swap_hands(diver)
t.equip(diver)
t.run_ticks(2)
assert(t.worn(diver).mask == "breath_mask", "the apparatus is back on")
t.swap_hands(diver)
t.use_self(diver)
t.run_ticks(2)
assert(t.vitals(diver).tank ~= nil, "and the same gesture opens the same tank")
