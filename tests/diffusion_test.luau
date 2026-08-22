-- Free gas, moving by itself. No pipe anywhere on any map below, no
-- machine, no vent, nobody switching anything on: just rooms, the walls
-- between them, and what the air does about it.
--
-- Everything else in the atmospherics suite is about the KIT. This is
-- the substrate under all of it: a room is one cell per TILE
-- (docs/MATTER.md §7), gas crosses between two of them only where there
-- is a link to cross (tg's `atmos_adjacent_turfs`,
-- `LINDA_system.dm:96-99`), and a wall is not a rule about gas -- it is
-- the absence of a cell to be linked to. A closed door and a glazed
-- pane seal their cell's links, and from down here there is no
-- difference between the three.
--
-- THE BOOKS ARE IN MOLES. A pressure that settled where you expected
-- proves nothing on its own -- an engine quietly making or destroying
-- gas would read perfectly on a gauge -- so every claim below is
-- weighed on `t.room_gas`, tile by tile and summed over the map.
-- Carbon dioxide is the tracer because nothing here can make or unmake
-- it: the one reaction in the roster is plasma fire, gated at 373.15 K
-- with no plasma in sight.
--
-- `t.foul_room` is precondition scaffolding standing in for lungs, the
-- same standing `t.set_health` has, and it is never an assertion.

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- Moles of one gas over a tile, and every gas over a tile. A walled
-- tile has no cell at all, so `t.room_gas` answers nil there and both
-- read zero -- which is the honest arithmetic, not a guard.
local function held(x, y, which)
    local gas = t.room_gas(x, y)
    return gas and gas[which] or 0.0
end

local function total(x, y)
    local sum = 0.0
    for _, moles in pairs(t.room_gas(x, y) or {}) do
        sum = sum + moles
    end
    return sum
end

local function sum_over(tiles, f, which)
    local s = 0.0
    for _, tile in ipairs(tiles) do
        s = s + f(tile[1], tile[2], which)
    end
    return s
end

-- ---------------------------------------------------------------
-- A DOORWAY IS A DOORWAY.
--
-- Two rooms of different sizes with one tile of floor joining them --
-- six tiles west, nine east, and the gap between makes sixteen. Foul
-- ONE tile of the west room with sixteen moles of carbon dioxide and
-- leave the station alone.
--
-- What has to come out is not "the east room went up a bit". It is one
-- mole of CO2 on every tile of both rooms, because sixteen moles
-- through sixteen cells is one mole each and the gap has no opinion
-- about which side of it a cell is on. The COMPOSITION equalises, not
-- merely the pressure -- a far room that came up to the same kPa on
-- nitrogen alone would pass a gauge test and kill somebody.
-- ---------------------------------------------------------------
t.world([==[(
    name: "doorway",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#..#...#",
        "#......#",
        "#..#...#",
        "########",
    ],
    spawns: [(6, 3)],
)]==], 7)

-- An INERT SKY, and every map in this file gets one. A hull radiating
-- against a sink at its own temperature emits exactly what it absorbs,
-- so nothing here cools -- by physics, not by a bypass flag. It matters
-- because the tiles of a room do not cool at the SAME rate: a corner is
-- bolted to two walls' worth of steel and a middle tile stands on its
-- own deck alone, so a cooling room grows a temperature map, and gas
-- drifts towards the cold. That is real (room_temperature_test.luau
-- weighs it), and it is not what this file is about: what is asserted
-- below is where gas goes when nothing is pushing it anywhere.
t.set_environment({ sink_k = 293.15, insolation = 0 })

t.join()
t.tick()

local WEST = { { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 }, { 1, 3 }, { 2, 3 } }
local GAP = { { 3, 2 } }
local EAST = {
    { 4, 1 }, { 5, 1 }, { 6, 1 },
    { 4, 2 }, { 5, 2 }, { 6, 2 },
    { 4, 3 }, { 5, 3 }, { 6, 3 },
}
local EVERY = {}
for _, room in ipairs({ WEST, GAP, EAST }) do
    for _, tile in ipairs(room) do
        EVERY[#EVERY + 1] = tile
    end
end
assert(#EVERY == 16, "sixteen tiles of station, and " .. #EVERY .. " counted")
assert(t.turf(3, 1) == "wall" and t.turf(3, 3) == "wall", "the dividing wall is a wall")
assert(t.turf(3, 2) == "floor", "with one tile of floor through it")

local air_0 = sum_over(EVERY, total)
near(t.room_pressure(2, 2), 101.325, 0.01, "the west room opens at one atmosphere")
near(t.room_pressure(6, 3), 101.325, 0.01, "and so does the east one")

t.foul_room(2, 2, "co2", 16.0)
t.tick()
near(held(2, 2, "co2"), 16.0, 1e-9, "all of it is standing on one tile")
assert(sum_over(EAST, held, "co2") == 0.0, "and none of it is next door yet")
near(t.room_pressure(6, 3), 101.325, 0.01, "which the far room's gauge agrees about")

-- Thirty seconds, which is what it takes. Nobody does anything.
t.run_seconds(35)

for _, tile in ipairs(EVERY) do
    near(
        held(tile[1], tile[2], "co2"),
        1.0,
        1e-6,
        "one mole on every tile, including " .. tile[1] .. "," .. tile[2]
    )
end
near(sum_over(WEST, held, "co2"), 6.0, 1e-6, "six moles' worth in the west room")
near(sum_over(EAST, held, "co2"), 9.0, 1e-6, "nine in the east one")
near(sum_over(GAP, held, "co2"), 1.0, 1e-6, "and one standing in the doorway")
near(sum_over(EVERY, held, "co2"), 16.0, 1e-6, "the sixteen that went in, no more")
near(sum_over(EVERY, total), air_0 + 16.0, 1e-6, "and the map's whole book with it")

-- And the gauges agree, last rather than first: the pressure is a
-- CONSEQUENCE of the moles being where they are.
local west_kpa = t.room_pressure(1, 1)
local east_kpa = t.room_pressure(6, 3)
near(west_kpa, east_kpa, 0.01, "both rooms settle at one pressure")
assert(west_kpa > 101.5, "which is above where they started: " .. west_kpa)

-- ---------------------------------------------------------------
-- A WALL IS NOT A SLOW DOORWAY.
--
-- The same experiment with the gap bricked up. The west room is fouled
-- and the east room's book is asserted EXACTLY -- not "near", not
-- "within a mole", but the same floating-point numbers it opened the
-- shift with, two minutes later.
--
-- Exactness is the point. A barrier leaking one part in a million would
-- pass every tolerance in this file and would still be a station whose
-- vault slowly fills with whatever the corridor is breathing. There is
-- no cell on the far side of a wall to be linked to, so there is no
-- arithmetic here to be nearly right.
-- ---------------------------------------------------------------
t.world([==[(
    name: "party wall",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#######",
        "#..#..#",
        "#..#..#",
        "#######",
    ],
    spawns: [(1, 1)],
)]==], 7)

t.set_environment({ sink_k = 293.15, insolation = 0 }) -- inert sky, as above

t.join()
t.tick()

local SEALED = { { 4, 1 }, { 5, 1 }, { 4, 2 }, { 5, 2 } }
local FOULED = { { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 } }

-- The neighbour's book, tile by tile, before anybody does anything.
local opening = {}
for n, tile in ipairs(SEALED) do
    opening[n] = {
        o2 = held(tile[1], tile[2], "o2"),
        n2 = held(tile[1], tile[2], "n2"),
        kpa = t.room_pressure(tile[1], tile[2]),
    }
    assert(opening[n].o2 > 0.0 and opening[n].n2 > 0.0, "the sealed room opens breathable")
end

t.foul_room(1, 1, "co2", 12.0)
t.run_seconds(120)

-- The fouled side did everything a fouled side does.
near(sum_over(FOULED, held, "co2"), 12.0, 1e-6, "the fouled room kept all twelve moles")
for _, tile in ipairs(FOULED) do
    near(
        held(tile[1], tile[2], "co2"),
        3.0,
        1e-6,
        "spread evenly across its own four tiles"
    )
end
assert(
    t.room_pressure(1, 1) > 106.0,
    "and it is over-pressured for it: " .. t.room_pressure(1, 1)
)

-- The sealed side did nothing whatsoever.
for n, tile in ipairs(SEALED) do
    local x, y = tile[1], tile[2]
    assert(
        held(x, y, "co2") == 0.0,
        "NOT ONE MOLE crossed the wall onto " .. x .. "," .. y
    )
    assert(
        held(x, y, "o2") == opening[n].o2,
        "and its oxygen is the same number, exactly: "
            .. held(x, y, "o2") .. " vs " .. opening[n].o2
    )
    assert(held(x, y, "n2") == opening[n].n2, "and its nitrogen")
    assert(t.room_pressure(x, y) == opening[n].kpa, "and its gauge never twitched")
end

-- ---------------------------------------------------------------
-- A CLOSED DOOR IS A WALL THAT CHANGES ITS MIND.
--
-- Same argument on the barrier that is not permanent. A closed airlock
-- seals its cell's links, the identical treatment a glazed pane gets
-- and nothing else to it (`Atmos::set_barrier_sealed`) -- so while it
-- is shut it must be as absolute as the wall above, and the tile UNDER
-- the leaf is its own sealed pocket that hears nothing either. Then a
-- crewman opens it, and what could not cross a moment ago crosses. The
-- breaker goes once the leaf is open, so what is watched is gas through
-- a doorway rather than autoclose timing (airlock_test.luau owns that).
-- ---------------------------------------------------------------
t.world([==[(
    name: "airlock between",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
        'D': (turf: Floor, fixture: Some(Door)),
    },
    rows: [
        "#######",
        "#..D..#",
        "#######",
    ],
    spawns: [(2, 1)],
)]==], 7)

t.set_environment({ sink_k = 293.15, insolation = 0 }) -- inert sky, as above

local p = t.join()
t.tick()

local NEAR = { { 1, 1 }, { 2, 1 } }
local LEAF = { { 3, 1 } }
local FAR = { { 4, 1 }, { 5, 1 } }
assert(not t.door_at(3, 1).open, "the airlock starts shut")

local far_kpa_0 = t.room_pressure(4, 1)
t.foul_room(1, 1, "co2", 10.0)
t.run_seconds(60)

-- Shut, it is the wall: exact on the far side, and exact under the leaf.
near(sum_over(NEAR, held, "co2"), 10.0, 1e-6, "all ten moles stayed this side")
near(held(1, 1, "co2"), 5.0, 1e-6, "spread over the two tiles that could reach")
assert(sum_over(LEAF, held, "co2") == 0.0, "the tile under the leaf is its own pocket")
assert(sum_over(FAR, held, "co2") == 0.0, "and the far room heard NOTHING")
assert(t.room_pressure(4, 1) == far_kpa_0, "its gauge did not move at all")

-- A hand on the door. The leaf takes tg's 0.6 s to swing, and then the
-- breaker goes so nothing tidies up after us -- a dead motor holds
-- whatever position it had.
t.click(p, 3, 1, t.target_at(3, 1))
t.run_ticks(15)
assert(t.door_at(3, 1).open, "the airlock opened")
t.outage()
t.run_ticks(20)
assert(t.door_at(3, 1).open, "and an unpowered leaf stays where it was left")

t.run_seconds(35)

-- Five tiles, ten moles: two on each, wherever it is standing.
for _, room in ipairs({ NEAR, LEAF, FAR }) do
    for _, tile in ipairs(room) do
        near(
            held(tile[1], tile[2], "co2"),
            2.0,
            1e-6,
            "two moles on " .. tile[1] .. "," .. tile[2] .. " once the door is open"
        )
    end
end
local crossed = sum_over(NEAR, held, "co2") + sum_over(LEAF, held, "co2")
near(crossed + sum_over(FAR, held, "co2"), 10.0, 1e-6, "still the ten that went in")
near(t.room_pressure(1, 1), t.room_pressure(5, 1), 0.01, "both rooms at one pressure")
assert(
    t.room_pressure(5, 1) > far_kpa_0,
    "the far room, which a shut door left untouched for a minute, is up: "
        .. far_kpa_0 .. " -> " .. t.room_pressure(5, 1)
)
