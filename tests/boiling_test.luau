-- Boil a beaker dry: what leaves the glass ends up in the room.
--
-- The chamber holds the vessel over water's boil, the phase step turns
-- the water to vapour inside the beaker (docs/CHEMISTRY.md), and the
-- beaker is OPEN -- so the vapour goes where an open vessel's gas phase
-- goes now, which is the air over the tile it is standing in
-- (sim/holder/vent.rs). Before that pass existed the vapour stayed
-- in the glass forever, counting against the fill and seen by nobody.
--
-- Nothing here is staged: the water came out of a button and the only
-- other thing a crewman did was turn a dial.
--
-- WHERE IT ENDS UP is the room's own arithmetic and not this spec's
-- claim -- a cell at station temperature condenses what it is handed,
-- so the water lands on the deck within a pass or two. What is
-- asserted is the crossing: the glass empties, and the room is where
-- the water went.
local PRESS = 0.75

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

-- What the sealed room holds of a GAS, over every tile of it.
local function room_gas(key)
    local n = 0
    for x = 1, 3 do
        for y = 1, 2 do
            local gases = t.room_gas(x, y)
            n = n + ((gases and gases[key]) or 0)
        end
    end
    return n
end

t.world([==[(
    name: "boiling bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#oag#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [(1, 1, "beaker")],
    machines: [(1, 2, "chem_dispenser"), (3, 2, "chem_heater")],
    cables: [
        (1, 1, 1, 0, 2), (1, 1, 1, 0, 4), (1, 1, 2, 0, 2), (1, 1, 2, 0, 4),
        (2, 1, 1, 0, 2), (2, 1, 1, 0, 4), (2, 1, 1, 0, 8), (2, 1, 2, 0, 2),
        (2, 1, 2, 0, 4), (2, 1, 2, 0, 8), (3, 1, 1, 0, 2), (3, 1, 1, 0, 8),
        (3, 1, 2, 0, 2), (3, 1, 2, 0, 8),
        (1, 2, 1, 0, 1), (1, 2, 1, 0, 4), (1, 2, 2, 0, 1), (1, 2, 2, 0, 4),
        (2, 2, 1, 0, 1), (2, 2, 1, 0, 4), (2, 2, 1, 0, 8), (2, 2, 2, 0, 1),
        (2, 2, 2, 0, 4), (2, 2, 2, 0, 8), (3, 2, 1, 0, 1), (3, 2, 1, 0, 8),
        (3, 2, 2, 0, 1), (3, 2, 2, 0, 8),
    ],
)]==], 0)

local p = t.join()
t.tick()

local dispenser = t.target_at(1, 2)
local heater = t.target_at(3, 2)
local beaker = t.target_at(1, 1, "beaker")

local function dock(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
end

-- ---------------------------------------------------------------
-- ONE: A PRESS OF WATER.
-- ---------------------------------------------------------------
t.click(p, 1, 1, beaker)
t.tick()
dock(dispenser, 1, 2)
assert(t.hands(p).held == nil, "the beaker is in the dispenser")
-- The panel is a window a crewman opens by clicking the machine; a
-- press only means anything to a session that has one open.
t.click(p, 1, 2, dispenser)
t.tick()
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
assert(math.abs(amount(beaker, "water") - PRESS) < 1e-9, "three quarters of a mole of water")
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "and it comes back out")

-- ---------------------------------------------------------------
-- TWO: PAST THE BOIL, AND OUT.
-- ---------------------------------------------------------------
dock(heater, 3, 2)
t.click(p, 3, 2, heater)
t.tick()
t.ui_act(p, "set", '{"field":"temperature","value":600}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"power"}')

-- The chamber has to get there before anything can leave, so watch for
-- the vapour rather than guessing the tick it appears on: the crossing
-- is a gas for as long as the room stays hot enough to hold it.
local saw_vapour = false
local saw_two_phases = false
for _ = 1, 400 do
    t.run_ticks(5)
    if room_gas("water") > 0.0 then
        saw_vapour = true
    end
    -- INSIDE THE GLASS, on the way out. `t.vessel` splits the water by
    -- phase, so a sample taken while the chamber is over the boil
    -- catches the beaker holding both at once: liquid still standing in
    -- the bottom and vapour in the headspace over it. That is the step
    -- the room's gain is made of -- water does not teleport from a
    -- beaker to a room, it boils into the space above itself and the
    -- open vessel breathes that space out (sim/holder/vent.rs).
    --
    -- Small when you catch it, and the cadence says why: the vent runs
    -- every atmos pass and takes the WHOLE headspace, so what a sample
    -- between passes finds is one pass's worth rather than a beaker
    -- full of steam. What is asserted is that the gas phase exists in
    -- there at all while the liquid one still does.
    local inside = t.vessel(beaker)
    local water = inside.contents.water
    if
        water ~= nil
        and (water.gas or 0) > 0
        and (water.liquid or 0) > 0
        and inside.temp_k > 373.0
    then
        saw_two_phases = true
    end
    if amount(beaker, "water") <= PRESS * 0.05 then
        break
    end
end

assert(saw_vapour, "the water crossed into the room as a gas")
assert(saw_two_phases, "and it was gas in the glass before it was gas in the room")
-- Nearly dry rather than exactly dry, and the arithmetic says why: the
-- phase step moves a share of what is left each time, so the last drops
-- go asymptotically. A twentieth of a press left after a hundred
-- seconds is a beaker that boiled away.
assert(
    amount(beaker, "water") <= PRESS * 0.05,
    "and the glass all but boiled dry: " .. amount(beaker, "water")
)
assert(t.holder_k(beaker) > 373.0, "the chamber held it over the boil the whole time")
