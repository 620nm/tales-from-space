-- Humidity: boil a beaker dry in a sealed room and the room stays
-- humid, instead of raining the water straight back onto the deck.
--
-- This is the smallest possible statement of what Effort G changed
-- about matter. The old phase step was a one-way ratchet -- it boiled
-- above the boiling point and condensed ALL vapour below it -- so a
-- kettle emptied into a room at station temperature made a puddle
-- within a pass or two, every time, however little water there was and
-- however much air there was to hold it. There was no such thing as
-- damp air.
--
-- Now vapour condenses only past its own dew point. A kilo of steam in
-- a broom closet still rains; a beaker's worth in a room this size is
-- nowhere near saturation and simply stays in the air, which is what
-- damp air IS. Nothing here is a new system: it is the same phase step,
-- asked the right question.
--
-- `t.room_gas` reports the GAS phase only (sim/vents.rs), which is what
-- makes the assertions below sharp: a puddle would read as zero.

t.world([==[(
    name: "the drying room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "######",
        "#..#g#",
        "#ao###",
        "######",
    ],
    spawns: [(1, 2)],
    items: [(2, 2, "beaker")],
    machines: [(1, 1, "chem_dispenser"), (2, 1, "chem_heater")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3),
        (1, 2, 3), (2, 2, 3),
    ],
)]==], 0)

local p = t.join()
t.run_ticks(2)

local dispenser = t.target_at(1, 1)
local heater = t.target_at(2, 1)
-- Taken while it is still standing on the deck: the handle is the
-- entity and outlives every move, but `t.target_at` can only find a
-- thing that is on a tile.
local beaker = t.target_at(2, 2, "beaker")

-- Water hanging in the closet's air, over every tile of it.
local function damp()
    local n = 0
    for x = 1, 2 do
        for y = 1, 2 do
            local gases = t.room_gas(x, y)
            n = n + ((gases and gases.water) or 0)
        end
    end
    return n
end

local function dock(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
end

local function panel(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
end

local function eject()
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
end

local function water_in(handle)
    local c = t.contents(handle)
    return (c and c.water) or 0
end

-- ---------------------------------------------------------------
-- ONE: A BEAKER OF WATER.
-- ---------------------------------------------------------------
t.click(p, 2, 2, beaker)
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the beaker is in hand")
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
local filled = water_in(beaker)
assert(filled > 1.0, "filled to the brim: " .. filled .. " mol")
-- All but dry: a beaker of water is evaporating into its own headspace
-- from the moment it is filled, and an open glass trades that headspace
-- with the room (sim/holder/vent.rs). Micromoles, against the moles the
-- boil below puts up.
assert(damp() < 1e-3, "and the closet is all but bone dry to start with")
eject()

-- ---------------------------------------------------------------
-- TWO: BOIL IT DRY.
--
-- 400 K, well past water's 373.15, so the boil branch runs flat out and
-- the gas leaves the open vessel for the room every pass
-- (sim/holder/vent.rs).
-- ---------------------------------------------------------------
dock(heater, 2, 1)
panel(heater, 2, 1)
t.ui_act(p, "set", '{"field":"temperature","value":400}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(600)
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)

local left = water_in(beaker)
assert(left < filled * 0.25, "most of it boiled away: " .. left .. " of " .. filled)

-- ---------------------------------------------------------------
-- THREE: AND THE ROOM KEEPS IT.
--
-- Power off, and two minutes of nothing at all. Before this effort
-- every mole of it would have been a puddle on the deck within a pass.
-- ---------------------------------------------------------------
local wet = damp()
assert(wet > 0.5, "the room is holding the water: " .. wet .. " mol")
t.run_seconds(120)
local still = damp()
assert(still > 0.5, "and still holding it two minutes later: " .. still .. " mol")
assert(
    math.abs(still - wet) < wet * 0.25,
    "settled rather than draining away: " .. wet .. " -> " .. still
)
