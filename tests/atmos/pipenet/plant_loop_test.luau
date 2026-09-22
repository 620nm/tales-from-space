local network_matter = require("@helpers/network_matter")
-- The whole atmospherics loop on one small plant: stores -> mixer ->
-- supply main -> vent -> ward, and ward -> scrubber -> layer-2 waste
-- main -> layer adapter -> CO2 filter -> the tank labelled for it.
--
-- Every other atmos spec proves one machine. This one proves they
-- compose into a loop a crew relies on: the ward keeps breathable air
-- over minutes, the carbon dioxide it is fouled with ends up in the
-- CO2 tank and nowhere else, and the ward torn open to space is held
-- off by the vent and refilled once it is sealed. The loop's shape is
-- the engine's `docs/atmos/station-loop.md`; fixture:
-- `tests/maps/plant_loop.ron`.

-- Nobody here breathes: the books below are the plumbing's own, and a
-- crewman's lungs would be a CO2 source in the middle of them.
t.set_breathing(false)
t.world_file("plant_loop.ron", 7)
t.join()
t.tick()

local WARD = { x = 3, y = 2 }
local SCRUBBER = { x = 5, y = 1 }
local CO2_TANK = { x = 11, y = 3 }
local N2_TANK = { x = 16, y = 5 }
local O2_TANK = { x = 13, y = 3 }
local WASTE_MAIN = { x = 6, y = 1 }
local FILTER_SIDE = { x = 11, y = 2 }
local SUPPLY_MAIN = { x = 12, y = 5 }
local BREACH = { { x = 1, y = 1 }, { x = 1, y = 2 }, { x = 1, y = 3 } }

local function ward_total(which: string): number
    local sum = 0.0
    for y = 1, 3 do
        for x = 1, 6 do
            local held = t.room_gas(x, y)
            sum = sum + ((held and held[which]) or 0.0)
        end
    end
    return sum
end

local function net_of(at: { x: number, y: number }, channel: string, which: string): number
    local held = network_matter.gas(at.x, at.y, channel)
    return (held and held[which]) or 0.0
end

local function co2_tank_holds(which: string): number
    local held = t.tank_gas(CO2_TANK.x, CO2_TANK.y)
    return (held and held[which]) or 0.0
end

local function stores(): number
    local n2 = t.tank_gas(N2_TANK.x, N2_TANK.y)
    local o2 = t.tank_gas(O2_TANK.x, O2_TANK.y)
    return ((n2 and n2.n2) or 0.0) + ((o2 and o2.o2) or 0.0)
end

local function co2_everywhere(): number
    return t.matter_totals().substances.co2 or 0.0
end

-- ---------------------------------------------------------------
-- ONE: THE WARD HOLDS BREATHABLE AIR, AND KEEPS HOLDING IT.
--
-- Not at roundstart: over three minutes, with the plant commissioned
-- and running. A loop that starts at an atmosphere and slowly loses it
-- is invisible to any spec that only looks at tick zero.
-- ---------------------------------------------------------------
local opening = assert(t.room_pressure(WARD.x, WARD.y))
assert(opening > 90.0 and opening < 115.0, "the ward opens breathable: " .. opening)
t.run_seconds(180)
local held = assert(t.room_pressure(WARD.x, WARD.y))
assert(
    held > 90.0 and held < 115.0,
    "and three minutes later it is still breathable: " .. opening .. " -> " .. held
)
local o2_share = ward_total("o2") / (ward_total("o2") + ward_total("n2"))
assert(o2_share > 0.19 and o2_share < 0.23, "still a fifth oxygen: " .. o2_share)
assert(
    assert(network_matter.pressure(SUPPLY_MAIN.x, SUPPLY_MAIN.y)) > 4000.0,
    "because the mixer holds the supply main charged behind the vent"
)

-- ---------------------------------------------------------------
-- TWO: A FOULED WARD COMES CLEAN, AND THE CARBON DIOXIDE ENDS UP IN
-- THE TANK LABELLED FOR IT.
--
-- Scrubber -> layer-2 waste main -> layer adapter -> layer-3 filter
-- intake -> side outlet -> tank. The gas is put on the scrubber's own
-- tile, standing in for lungs, and every mole of it is accounted for.
-- ---------------------------------------------------------------
assert(co2_everywhere() == 0.0, "the shift opens with no carbon dioxide anywhere")
local FOULED = 4.0
assert(t.foul_room(SCRUBBER.x, SCRUBBER.y, "co2", FOULED))
t.tick()
assert(ward_total("co2") > FOULED * 0.99, "the ward has carbon dioxide in it now")

t.run_seconds(180)
local ward_left = ward_total("co2")
local in_tank = co2_tank_holds("co2")
local in_waste = net_of(WASTE_MAIN, "l2", "co2")
local in_side = net_of(FILTER_SIDE, "l3", "co2")
assert(ward_left < FOULED * 0.1, "the scrubber took it back out of the ward: " .. ward_left)
assert(in_tank > FOULED * 0.5, "and the filter put it in the CO2 tank: " .. in_tank)
assert(
    math.abs(co2_everywhere() - FOULED) < 1e-9,
    "the loop made and lost none of it: " .. co2_everywhere()
)
assert(
    math.abs(ward_left + in_waste + in_side + in_tank - FOULED) < 1e-6,
    "and every mole is in the ward or the loop: "
        .. ward_left
        .. " + "
        .. in_waste
        .. " + "
        .. in_side
        .. " + "
        .. in_tank
)

-- ---------------------------------------------------------------
-- THREE: A BREACHED WARD, RESEALED, REFILLS FROM THE SUPPLY MAIN.
--
-- Three tiles of the ward's deck opened to space: the vent fights the
-- hole off the plant's stores rather than losing the room to vacuum,
-- and once the deck is back the same vent refills it with nobody
-- carrying a canister anywhere.
-- ---------------------------------------------------------------
local before_breach = assert(t.room_pressure(WARD.x, WARD.y))
local stores_before = stores()
assert(before_breach > 90.0, "the ward is pressurised: " .. before_breach)
for _, tile in ipairs(BREACH) do
    assert(t.set_composition(tile.x, tile.y, "bare"))
end
t.run_seconds(90)
local breached = assert(t.room_pressure(WARD.x, WARD.y))
assert(
    breached < before_breach * 0.7,
    "opening the deck costs the ward most of its air: " .. before_breach .. " -> " .. breached
)
assert(breached > 5.0, "and the supply is still fighting it: " .. breached)

for _, tile in ipairs(BREACH) do
    assert(t.set_composition(tile.x, tile.y, "floor"))
end
t.run_seconds(120)
local recovered = assert(t.room_pressure(WARD.x, WARD.y))
assert(
    recovered > 90.0,
    "and sealed, the plant puts the air back: " .. breached .. " -> " .. recovered .. " kPa"
)
assert(stores() < stores_before - 100.0, "out of the stores: " .. stores_before .. " -> " .. stores())
assert(
    co2_tank_holds("co2") >= in_tank - 1e-9,
    "while the CO2 tank kept every mole it caught: " .. in_tank .. " -> " .. co2_tank_holds("co2")
)
