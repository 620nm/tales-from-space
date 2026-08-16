-- Building a pressure tank, and cutting one back open.
--
-- tg's chain, adapted only in its material (tank.dm:560-697, plus the
-- stack recipe at sheet_types.dm:297): four sheets stand a frame up,
-- a wrench bolts it down, twelve more plate it, a torch seals it into
-- the vessel. Backwards: a torch cuts the vessel open, a crowbar prises
-- the plating off, a screwdriver takes the bare frame apart -- and each
-- step hands back exactly what it cost. tg spends plasteel on the frame
-- and any rigid material on the plating; this station has neither
-- plasteel nor material classes, so metal stands in for both and tg's
-- COUNTS are kept.
--
-- What makes this worth a spec of its own is the last line of tg's
-- `on_deconstruction`: `location.assume_air(air_contents)`
-- (tank.dm:433-436). A vessel cannot be deleted with its moles still
-- in it -- that would be the one place in the engine where matter
-- stops existing -- so cutting a full tank open empties it into the
-- room you are standing in.

t.world([==[(
    name: "fabrication bay",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(2, 2)],
    items: [(2, 1, "metal"), (2, 3, "wrench"), (2, 1, "welder")],
    // A charged tank at the far end of one length of pipe. It is here
    // so the tank BUILT below has something to fill from: a vessel's
    // mouths are pipe ports and nothing else, exactly as tg's are, so
    // there is no way to put gas in one out of the room around it.
    structures: [
        (5, 2, "stationary_tank", "anchored", ("plasma", 2000.0)),
    ],
    pipes: [(4, 2, 4)],
)]==], 7)

local p = t.join()
t.tick()
local charged_start = t.tank_pressure(5, 2)
assert(math.abs(charged_start - 2000.0) < 20.0,
    "the map's tank opens holding what the map said: " .. charged_start)
t.click(p, 2, 1, t.target_at(2, 1, "metal")) -- a pile of thirty
t.run_ticks(2)
t.swap_hands(p)
t.click(p, 2, 3, t.target_at(2, 3, "wrench"))
t.run_ticks(2)
t.swap_hands(p) -- the sheets are the active hand again

-- ---------------------------------------------------------------
-- Four sheets, one second: tg's "Large Gas Tank" stack recipe. It
-- rises DISPLACED, because tg's does (`anchored = FALSE`).
--
-- From the build window rather than by clicking the deck: metal makes
-- girders, machine frames and tank frames, and a bare click has to
-- take the first of them. Naming the row is what a player does too.
-- ---------------------------------------------------------------
t.build(p, "metal", "stationary_tank_frame", 3, 2)
t.run_seconds(1.5)
local frame = t.structure_at(3, 2)
assert(frame and frame.id == "stationary_tank_frame",
    "four sheets make a tank frame: " .. tostring(frame and frame.id))
assert(frame.state == "displaced", "and it is not bolted yet: " .. tostring(frame.state))

-- No plating onto a frame that slides when you lean on it. tg makes the
-- same point one step later, at the welder ("You need to wrench [src]
-- to the floor before finishing", tank.dm:680-682); refusing it here
-- says which state the job wants instead of starting work that cannot
-- finish.
local _ = t.messages(p)
t.click(p, 3, 2, t.target_at(3, 2))
t.run_ticks(2)
local refused = false
for _, m in ipairs(t.messages(p)) do
    if m == "The tank frame must be anchored first." then
        refused = true
    end
    assert(m ~= "You start plating the tank frame.", "the work never started")
end
assert(refused, "an unbolted frame takes no plating, and says so")

-- ---------------------------------------------------------------
-- Bolt it, plate it, seal it. tg's 0.5 s / 3 s / 2 s.
-- ---------------------------------------------------------------
t.swap_hands(p) -- the wrench
t.click(p, 3, 2, t.target_at(3, 2))
t.run_seconds(1.0)
assert(t.structure_at(3, 2).state == "anchored", "the wrench bolts it down")

t.swap_hands(p) -- the sheets
t.click(p, 3, 2, t.target_at(3, 2))
t.run_seconds(3.5)
assert(t.structure_at(3, 2).state == "plated", "twelve more sheets plate it")

t.swap_hands(p) -- put the wrench down and take the torch
t.drop(p)
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1, "welder"))
t.run_ticks(2)
t.click(p, 3, 2, t.target_at(3, 2))
t.run_seconds(2.5)
local tank = t.structure_at(3, 2)
assert(tank and tank.id == "stationary_tank",
    "the torch seals it into a vessel: " .. tostring(tank and tank.id))
-- It brings NO GAS OF ITS OWN. tg's base type ships `gas_type = null`
-- (tank.dm:41) and everything that opens the shift full is a map
-- saying so -- welding one shut conjures nothing. What it does bring
-- is four open mouths, so it is part of the plumbing from the very
-- next pass: whatever is in it a moment later came down the pipe, and
-- the tank at the other end is a moment lighter for it.
local sealed = t.tank_pressure(3, 2)
assert(sealed < charged_start * 0.5,
    "a new vessel starts near enough empty: " .. sealed .. " kPa")
assert(t.tank_pressure(5, 2) < charged_start,
    "and every mole in it came out of the neighbour")

-- ---------------------------------------------------------------
-- Left alone, the run and both vessels settle into one body of gas --
-- tg's `reconcile_air` over a `custom_reconcilation` component. Then
-- cut the new one open, and the gas has to land on the deck.
-- ---------------------------------------------------------------
t.run_seconds(10)
local held = t.tank_pressure(3, 2)
assert(held > sealed + 100.0,
    "the new vessel goes on filling: " .. sealed .. " -> " .. held)
assert(math.abs(held - t.tank_pressure(5, 2)) < 50.0,
    "two tanks on one run settle to one pressure: "
        .. held .. " vs " .. t.tank_pressure(5, 2))
local room_before = t.room_gas(3, 2).plasma or 0.0

t.click(p, 3, 2, t.target_at(3, 2))
t.run_seconds(4.5)
local left = t.structure_at(3, 2)
assert(left and left.id == "stationary_tank_frame",
    "cutting it open leaves the re-platable frame: " .. tostring(left and left.id))
assert(t.tank_pressure(3, 2) == nil, "and no vessel at all")
assert(t.count_items("metal") > 0, "the plating comes back as sheets")

local room_after = t.room_gas(3, 2).plasma or 0.0
assert(room_after > room_before,
    "the contents landed on the deck: " .. room_before .. " -> " .. room_after)
assert(t.ledger_has("StructureStep", "stationary_tank", "gone"),
    "and cutting a pressure vessel open is on the record")
