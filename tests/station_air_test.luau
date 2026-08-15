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
-- in docs/matter.md §19.5; what is here is whether it WORKS.

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
local COMMONS = { 8, 8 }
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
local CO2_CHAMBER = { 25, 24 }
local chamber_0 = room_of(CO2_CHAMBER[1], CO2_CHAMBER[2], "co2")
assert(chamber_0 > 0.0, "the CO2 chamber opens holding carbon dioxide: " .. chamber_0)

-- Foul the tile the scrubber stands on, which is how a real one would
-- meet it: gas reaches a scrubber by spreading, not by being aimed.
t.foul_room(13, 8, "co2", 4.0)
t.tick()
local fouled = room_of(13, 8, "co2")
assert(fouled > 3.0, "the Commons has carbon dioxide in it now: " .. fouled)

t.run_seconds(240)
local left = room_of(13, 8, "co2")
assert(
    left < fouled * 0.5,
    "the scrubber took most of it back: " .. fouled .. " -> " .. left
)
local chamber_1 = room_of(CO2_CHAMBER[1], CO2_CHAMBER[2], "co2")
assert(
    chamber_1 > chamber_0,
    "and it ended up in the CO2 chamber, which is the whole loop: "
        .. chamber_0 .. " -> " .. chamber_1
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
local valve = t.structure_at(15, 19)
assert(valve ~= nil and valve.id == "manual_valve", "the wheel is where the map put it")
assert(valve.state == "open", "and it ships open: " .. tostring(valve.state))
assert(t.pipe_pressure(15, 18, L3) ~= nil, "there is feed above it")
assert(t.pipe_pressure(15, 20, L3) ~= nil, "and feed below it")

-- Walk an engineer to it. A manual valve has no panel by design (tg
-- gives it none: "Intentionally no allow_silicon flag") -- the wheel is
-- the whole interface, and you have to be standing there.
local function walk(dir, times)
    for _ = 1, times do
        t.move(p, dir)
        t.run_ticks(5)
    end
end
-- The route the demo screenshot walks, which is the only way in:
-- east through the Commons and the Annex, pin west against the shaft
-- wall so the count cannot drift, then south through the bulkhead door
-- at (17, 12) and down the feed to the wheel.
-- Pinned against two walls first, so the route cannot drift with
-- whatever the last scenario left the engineer standing on.
walk("west", 10)  -- pins on the Commons' west wall, x = 5
walk("north", 8)  -- and its north wall, y = 5
walk("south", 3)
walk("east", 12)
walk("south", 2)
walk("west", 5)   -- pins against the shaft's west wall at x = 15
walk("east", 2)   -- ...so this lands on the door column, x = 17
walk("south", 5)  -- one press opens the bulkhead door, the rest walk it
-- ...and inside the hall, pinned again rather than counted: west onto
-- the feed column, then south to the far wall, which puts the engineer
-- one tile past the wheel with their hand on it.
-- South FIRST: the storage canisters on the row below the door are
-- dense, so a west leg taken up there walks into one.
walk("south", 10)
walk("west", 15)
local px, py = t.pos(p)
assert(px == 15 and py == 20, "standing at the wheel, at " .. px .. "," .. py)

assert(t.structure_at(15, 19).state == "open", "still open on the way in")
t.click(p, 15, 19, t.target_at(15, 19, "manual_valve"))
t.run_seconds(3)
assert(
    t.structure_at(15, 19).state == "shut",
    "an empty hand shuts it: " .. tostring(t.structure_at(15, 19).state)
)

-- What isolation actually looks like, given time. Below the wheel the
-- chambers' injectors keep emptying the feed into their tanks and
-- nothing upstream can reach it any more, so that side runs down to
-- nothing; above it the department carries on. One wheel, two fates --
-- which is the difference between cutting a leg out and stopping the
-- station.
local below_0 = t.pipe_pressure(15, 20, L3)
assert(below_0 > 20.0, "the chamber feed was charged when it was shut: " .. below_0)
t.run_seconds(180)
local above_1 = t.pipe_pressure(15, 18, L3)
local below_1 = t.pipe_pressure(15, 20, L3)
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

-- The Commons is the room with vents in it, so it is the room distro
-- can actually put air back into. Open its west wall to space, which is
-- what a breach IS here -- there is no breach STATE, only a floor that
-- became space (CLAUDE.md).
for _, y in ipairs({ 7, 8, 9 }) do
    t.set_turf(5, y, "space")
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

for _, y in ipairs({ 7, 8, 9 }) do
    t.set_turf(5, y, "floor")
end
t.run_seconds(600)
local recovered = t.room_pressure(COMMONS[1], COMMONS[2])
assert(
    recovered > breached + 10.0,
    "and sealed, the station puts the air back: "
        .. breached .. " -> " .. recovered .. " kPa"
)
