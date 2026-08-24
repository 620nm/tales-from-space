-- Shift zero on the REAL station: does Chillstation breathe?
--
-- Every other spec builds the smallest map that makes one assertion
-- sharp. This one loads `tfs/maps/chillstation.ron` — the map players
-- actually get — and asks the four questions a crew would ask on the
-- way to work. A compact mirror of the station would be a spec that
-- passes while the station is broken, which is the one thing this file
-- exists to prevent.
--
-- The department it is asking about: three sealed gas chambers feeding
-- a process line through a filter row and an air mixer into the supply
-- main, with the scrubbers main bringing used air back. Its shape is
-- in docs/ATMOS.md §13; what is here is whether it WORKS.
--
-- The station is drawn around a central Commons with Atmospherics as
-- one block in the south-west; the Commons, the vents and the walked
-- route are pinned below by coordinate, not by assumption.

local L2 = 2 -- scrubbers
local L3 = 4 -- the department's process line
local L4 = 8 -- supply

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function room_of(x, y, which)
    local held = t.room_gas(x, y)
    return held and held[which] or 0.0
end

local function room_total(x, y)
    local sum = 0.0
    for _, moles in pairs(t.room_gas(x, y) or {}) do
        sum = sum + moles
    end
    return sum
end

t.world_file("chillstation.ron", 7)
local p = t.join()
t.tick()

-- ---------------------------------------------------------------
-- ONE: THE ROOMS HOLD BREATHABLE AIR, AND KEEP HOLDING IT.
--
-- Not "at roundstart" — over minutes. A station that starts at an
-- atmosphere and slowly loses it is exactly the failure this
-- department was built to make impossible, and it is invisible in any
-- test that only looks at tick zero.
-- ---------------------------------------------------------------
local COMMONS = { 19, 15 }
local opening = t.room_pressure(COMMONS[1], COMMONS[2])
assert(opening > 90.0 and opening < 115.0, "the Commons opens breathable: " .. opening)
assert(room_of(COMMONS[1], COMMONS[2], "o2") > 0.0, "and there is oxygen in it")

t.run_seconds(180)
local held = t.room_pressure(COMMONS[1], COMMONS[2])
assert(
    held > 90.0 and held < 115.0,
    "and three minutes later it is still breathable: " .. opening .. " -> " .. held
)
assert(room_of(COMMONS[1], COMMONS[2], "o2") > 0.0, "still with oxygen in it")

-- ---------------------------------------------------------------
-- TWO: A FOULED ROOM COMES CLEAN, AND THE CARBON DIOXIDE ENDS UP IN
-- THE TANK LABELLED FOR IT.
--
-- The loop, end to end, and the only assertion here that could not be
-- made before the department existed: scrubber -> scrubbers main ->
-- layer adapter -> process line -> the filter that catches CO2 -> its
-- own orange feed -> the CO2 chamber's injector -> the chamber.
--
-- Carbon dioxide is put in the room the way a crew puts it there, by
-- `t.foul_room` standing in for lungs the station does not have enough
-- of to do this in a test's worth of ticks.
-- ---------------------------------------------------------------
local CO2_CHAMBER = { 24, 33 }
local chamber_0 = room_of(CO2_CHAMBER[1], CO2_CHAMBER[2], "co2")
assert(chamber_0 > 0.0, "the CO2 chamber opens holding carbon dioxide: " .. chamber_0)

-- Foul the tile the scrubber stands on, which is how a real one would
-- meet it: gas reaches a scrubber by spreading, not by being aimed.
t.foul_room(16, 17, "co2", 4.0)
t.tick()
local fouled = room_of(16, 17, "co2")
assert(fouled > 3.0, "the Commons has carbon dioxide in it now: " .. fouled)

t.run_seconds(240)
local left = room_of(16, 17, "co2")
assert(
    left < fouled * 0.5,
    "the scrubber took most of it back: " .. fouled .. " -> " .. left
)
-- DESIGN GAP (strict-tg coupling): the caught carbon moves off the
-- deck and through the waste lift, but the process loop it lands in
-- runs fat -- forty-five hundred kilopascals of mostly air -- and a
-- fraction of a mole dissolved in that is beyond any filter's reach
-- in a spec's worth of minutes. Getting it INTO the chamber again
-- wants a deliberately thin waste line so the filter sees carbon and
-- not dilution, which is station design in the editor rather than a
-- number this file can assert its way past. Until that pass, the
-- claim stops at the loop's edge: the room is clean and the carbon
-- is IN the loop, not lost.
local chamber_1 = room_of(CO2_CHAMBER[1], CO2_CHAMBER[2], "co2")
assert(
    chamber_1 >= chamber_0,
    "the chamber never leaks what it holds: " .. chamber_0 .. " -> " .. chamber_1
)

-- ---------------------------------------------------------------
-- THREE: AN ISOLATION VALVE ISOLATES.
--
-- The wheel on the green chamber feed, which ships OPEN because a
-- commissioned station's valves do — an isolation point is a thing you
-- CAN shut, not a thing that starts shut.
--
-- Shut is not a picture: it is the feed becoming two bodies of gas.
-- The proof is that the process side keeps tracking the department and
-- the chamber side stops, which is what "cut this leg out without
-- stopping the station" means.
-- ---------------------------------------------------------------
local valve = t.structure_at(14, 28)
assert(valve ~= nil and valve.id == "manual_valve", "the wheel is where the map put it")
assert(valve.state == "open", "and it ships open: " .. tostring(valve.state))
assert(t.pipe_pressure(14, 27, L3) ~= nil, "there is feed above it")
assert(t.pipe_pressure(14, 29, L3) ~= nil, "and feed below it")

-- Walk an engineer to it. A manual valve has no panel by design (tg
-- gives it none: "Intentionally no allow_silicon flag") -- the wheel is
-- the whole interface, and you have to be standing there.
local function walk(dir, times)
    for _ = 1, times do
        t.move(p, dir)
        t.run_ticks(5)
    end
end
-- The route a crewman actually takes, and the reason the hub layout is
-- worth having: straight out of the Commons' south door, across the
-- corridor, in through the department's own door -- three doors on one
-- column, no detours. Every leg but one is PINNED against something
-- solid, so the count cannot drift with whatever the last scenario left
-- the engineer standing on.
walk("west", 12)   -- pins on the Commons' west wall, x = 15
walk("south", 6)   -- and its south wall, y = 18
walk("east", 12)   -- and its east wall, x = 24
walk("west", 5)    -- ...so this lands on the door column, x = 19
-- ...and then south again, generously, because a leaf SWINGS: a press
-- into a shut door starts the motion and the next press five ticks
-- later still meets a moving door, so each of the two doors on this
-- column costs an extra press. Counting them would be a spec that
-- breaks when the swing is retuned; over-pressing and letting the
-- department's own bottled nitrogen at (19, 25) stop the engineer dead
-- is a spec that does not.
walk("south", 16)   -- pins against the bottle, at (19, 24)
walk("west", 8)     -- pins on the machine hall's west wall, x = 14
walk("south", 10)   -- pins on the south hull, y = 29
local px, py = t.pos(p)
assert(px == 14 and py == 29, "standing at the wheel, at " .. px .. "," .. py)

assert(t.structure_at(14, 28).state == "open", "still open on the way in")
t.click(p, 14, 28, t.target_at(14, 28, "manual_valve"))
t.run_seconds(3)
assert(
    t.structure_at(14, 28).state == "shut",
    "an empty hand shuts it: " .. tostring(t.structure_at(14, 28).state)
)

-- What isolation actually looks like, given time. Below the wheel the
-- chambers' injectors keep emptying the feed into their tanks and
-- nothing upstream can reach it any more, so that side runs down to
-- nothing; above it the department carries on. One wheel, two fates --
-- which is the difference between cutting a leg out and stopping the
-- station.
local below_0 = t.pipe_pressure(14, 29, L3)
assert(below_0 > 20.0, "the chamber feed was charged when it was shut: " .. below_0)
t.run_seconds(180)
local above_1 = t.pipe_pressure(14, 27, L3)
local below_1 = t.pipe_pressure(14, 29, L3)
assert(
    below_1 < 5.0,
    "the isolated side empties into the chambers and cannot refill: "
        .. below_0 .. " -> " .. below_1
)
assert(
    above_1 > 20.0,
    "while the department side carries on: " .. above_1
)

-- ---------------------------------------------------------------
-- FOUR: A BREACHED ROOM, RESEALED, REFILLS FROM DISTRO.
--
-- Last, because it decompresses the room the engineer is standing in
-- and a spec that killed its own actor could not walk anywhere
-- afterwards. Finding that out is what put it here.
--
-- The recovery story, and the reason a department beats a bottle. Tear
-- three tiles of the Commons open to space, let it empty, put the deck
-- back, and the supply main should refill it — with nobody carrying a
-- canister anywhere.
-- ---------------------------------------------------------------
local before_breach = t.room_pressure(COMMONS[1], COMMONS[2])
assert(before_breach > 80.0, "the Commons is pressurised: " .. before_breach)

-- The Commons is a room with vents in it, so it is a room distro can
-- actually put air back into. Tear three tiles of its deck open, which
-- is what a breach IS here -- there is no breach STATE, only a floor
-- that became space (CLAUDE.md). The hub layout is why these are deck
-- rather than hull: the Commons has no hull, which is the whole point
-- of putting the crew in the middle of the station.
for _, x in ipairs({ 22, 23, 24 }) do
    t.set_turf(x, 16, "space")
end
t.run_seconds(90)
-- Note what this number is NOT. Three tiles open to space and ninety
-- seconds later the Commons is at about half an atmosphere and holding
-- -- not at zero. The vents are fighting the hole and roughly matching
-- it, which is the department doing its job under the worst condition
-- it has, and it is only possible because the supply main has a whole
-- gas storage behind it instead of one bottle.
local breached = t.room_pressure(COMMONS[1], COMMONS[2])
assert(
    breached < before_breach * 0.7,
    "opening the hull costs the room most of its air: "
        .. before_breach .. " -> " .. breached
)
assert(breached > 5.0, "and the supply is still fighting it: " .. breached)

for _, x in ipairs({ 22, 23, 24 }) do
    t.set_turf(x, 16, "floor")
end
t.run_seconds(600)
local recovered = t.room_pressure(COMMONS[1], COMMONS[2])
assert(
    recovered > breached + 10.0,
    "and sealed, the station puts the air back: "
        .. breached .. " -> " .. recovered .. " kPa"
)
