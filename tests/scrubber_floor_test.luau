-- The scrubber's FLOOR: the one thing about this machine that is not
-- tg's, and the reason a station on a radiating hull stays habitable.
--
-- room_devices_test.luau has tg's scrubber -- pointed at one gas, dial
-- wide open, nothing under it, taking that gas to the last mole. This
-- file has the other machine the same sprite can be: a RETURN GRILLE.
--
-- Why there is a second machine at all. tg's hull does not lose heat,
-- so a tg air loop only ever has to carry gases AWAY; ours radiates,
-- and a room left alone goes from shirtsleeves to freezing in about
-- fifty minutes. The loop that answers that is a heating loop -- bulk
-- room air down the waste main, separated and reheated by the plant,
-- handed back by the supply vent -- and the machine at the room end of
-- it is this one, drawing whole air rather than sieving it.
--
-- A grille with no floor would be a siphon with better manners, so this
-- one stops at a pressure. That is the whole deviation, and the reason
-- for it is the failure mode: a return grille that outruns its supply
-- leaves a room COLD, which is survivable, rather than a room in
-- VACUUM, which is not. Every assertion below is about where it stops.
--
-- The floor sits just under the supply vent's release line (0.99 atm),
-- and the gap between the two is the circulation: the room is always a
-- little under the line the vent works to, so the vent is always
-- feeding and the grille is always returning.

local ONE_ATM = 101.325
local SUPPLIES_UNDER = ONE_ATM * 0.99
local R, T20C = 8.314, 293.15

-- What a scrubber a MAPPER puts down is set to, which is not what the
-- content file gives one an engineer BUILDS (structures/props.rs).
local PLACED_RATE = 25.0
local PLACED_FLOOR = 100.0

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- The room is six tiles by two, one cubic metre each.
local ROOM = {}
for x = 1, 6 do
    for y = 1, 2 do
        ROOM[#ROOM + 1] = { x, y }
    end
end

-- Moles of one gas over the whole room, or of everything in it. A room
-- is one cell per TILE and the scrubber only ever works the tile it
-- stands on, so anything asserted about a room emptying or holding
-- still is asserted on the conserved quantity and never off one tile.
local function room_moles(which)
    local n = 0.0
    for _, tile in ipairs(ROOM) do
        for gas, amount in pairs(t.room_gas(tile[1], tile[2]) or {}) do
            if which == nil or gas == which then
                n = n + amount
            end
        end
    end
    return n
end

-- ...and that as a PRESSURE: the room's moles spread over its tiles.
-- Reading one tile would be reading the machine's own mouth, which
-- sloshes for a long time after anything happens to a room.
local function room_kpa(which)
    return room_moles(which) * R * T20C / (#ROOM * 1000.0)
end

local function pipe_moles(x, y, layer)
    local n = 0.0
    for _, amount in pairs(t.pipe_gas(x, y, layer) or {}) do
        n = n + amount
    end
    return n
end

-- ---------------------------------------------------------------
-- WITH NOTHING FEEDING IT, A GRILLE STOPS AT ITS FLOOR.
--
-- The failure this deviation exists to produce. Kill the supply, leave
-- the return running, and the room must come DOWN to the floor and
-- stay there -- a cold room, not an empty one. The same map with tg's
-- machine on it would end in vacuum with the crew in it.
--
-- One crewman joins, to read the machine's own panel and prove that a
-- placement that says nothing got what this file claims it got. They
-- breathe on the mole books, which costs nothing here: a lung swaps
-- oxygen for carbon dioxide roughly mole for mole, and every assertion
-- below is on the room's PRESSURE.
-- ---------------------------------------------------------------
local DEAD_SUPPLY = [==[(
    name: "return grille, no supply",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#....ag#",
        "########",
    ],
    spawns: [(3, 1)],
    // The waste main runs out under the west wall, so the room's air
    // has somewhere to go that is not the room. Layer 2, where a
    // scrubber lives.
    pipes: [(0, 1, 2), (1, 1, 2)],
    // Placed and SILENT, which is the whole point: a placement that
    // says nothing is a return grille, and this file is what that
    // means. It is put down running, the way a commissioned station's
    // machines are.
    structures: [(2, 1, "air_scrubber", "scrubbing")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==]

t.world(DEAD_SUPPLY, 7)
-- An INERT SKY. A hull radiating against a sink at its own temperature
-- emits exactly what it absorbs, so nothing here cools -- by physics,
-- not by a bypass flag. Without it a bench watched for minutes is also
-- watching the room bleed heat into space, and a room that cooled two
-- kelvin reads a kilopascal light on the very gauge this file asserts
-- against.
t.set_environment({ sink_k = 293.15, insolation = 0 })
t.tick()

local machine = t.structure_at(2, 1)
assert(machine ~= nil and machine.id == "air_scrubber", "the map stood one there")
assert(machine.state == "scrubbing", "running, and wearing the ordinary picture")
assert(
    machine.sprite ~= nil and string.find(machine.sprite, "purge") == nil,
    "a return grille must never be drawn as a room being emptied: "
        .. tostring(machine.sprite)
)

-- What a silent placement actually got, read off the machine's own
-- panel rather than assumed.
local p = t.join()
t.tick()
t.click(p, 2, 1, t.target_at(2, 1, "air_scrubber"))
t.tick()
local panel = t.ui(p)
assert(panel ~= nil, "a scrubber wears a panel")
assert(panel.setpoints[1].field == "rate", "a rate")
near(panel.setpoints[1].value, PLACED_RATE, 0.001, "gentle, not tg's 200")
assert(panel.setpoints[2].field == "floor", "and a floor")
near(panel.setpoints[2].value, PLACED_FLOOR, 0.001, "just under the vent's line")
assert(
    panel.setpoints[2].value < SUPPLIES_UNDER,
    "which is the circulation: the room sits below the line the vent"
        .. " works to, so the vent is always feeding -- "
        .. panel.setpoints[2].value .. " against " .. SUPPLIES_UNDER
)
local shape = nil
for _, sw in ipairs(panel.toggles) do
    if sw.field == "roster" then
        shape = sw
    end
end
assert(shape ~= nil and shape.on == true, "and it takes the whole mixture")

-- Overfill the room, so there is something to come down FROM and the
-- floor is a place it stops rather than a place it started.
for _, tile in ipairs(ROOM) do
    assert(t.foul_room(tile[1], tile[2], "n2", 10.0), "gas goes into every tile")
end
t.tick()
local fouled = room_kpa()
assert(fouled > 120.0, "the room is well over its floor: " .. fouled .. " kPa")

t.run_seconds(240)
local settled = room_kpa()
near(settled, PLACED_FLOOR, 2.0, "the room came down to the floor and stopped")
assert(
    settled > PLACED_FLOOR - 2.0,
    "and it is a FLOOR, not a target it can undershoot: " .. settled .. " kPa"
)

-- ...and stays there. A machine that stopped for a tick and then
-- carried on would look identical to one that stopped, for a tick.
t.run_seconds(240)
local held = room_kpa()
near(held, settled, 1.0, "four more minutes and it has not moved")
assert(held > 90.0, "a cold room, never an empty one: " .. held .. " kPa")

-- The books, across the room/net boundary. Nothing else on this map
-- moves gas, so what left one side is standing on the other.
assert(
    pipe_moles(1, 1, 2) > 100.0,
    "and the surplus is in the waste main, where the plant would find"
        .. " it: " .. pipe_moles(1, 1, 2) .. " mol"
)

-- ---------------------------------------------------------------
-- WITH A SUPPLY BEHIND IT, IT NEVER STOPS.
--
-- The other half of the same number. A grille whose floor sat ABOVE
-- the vent's release line would stall with both machines idle and the
-- room would slowly freeze anyway; one just below it means the room is
-- permanently a little under the line the vent works to, so gas is
-- always moving. That is what a heating loop is: not a reservoir, a
-- CURRENT.
--
-- Same room, plus a vent on a charged run at the far end.
-- ---------------------------------------------------------------
local LIVE_SUPPLY = [==[(
    name: "return grille, live supply",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#....ag#",
        "########",
    ],
    spawns: [(5, 2)],
    // Two runs sharing one corridor and never meeting, which is what
    // the layer convention is for: the waste main on L2 under the
    // grille, the supply on L4 between the bottle and the vent.
    pipes: [(0, 1, 2), (1, 1, 2), (4, 1, 8)],
    air_presets: {
        "canister_air": (gases: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15),
    },
    structures: [
        (2, 1, "air_scrubber", "scrubbing"),
        (5, 1, "vent"),
        (3, 1, "connector_port"),
        (3, 1, "canister", { "air": "canister_air", "open": true }),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==]

t.world(LIVE_SUPPLY, 7)
t.set_environment({ sink_k = 293.15, insolation = 0 })
t.tick()

assert(t.structure_at(5, 1).id == "vent", "a supply vent at the far end")
assert(t.canister_pressure(3, 1) > 4000.0, "on a full bottle")

t.run_seconds(30)
local early = pipe_moles(1, 1, 2)
local room_early = room_kpa()
t.run_seconds(120)
local mid = pipe_moles(1, 1, 2)
t.run_seconds(120)
local late = pipe_moles(1, 1, 2)

assert(mid > early + 1.0, "moles keep arriving in the waste main: " .. early .. " -> " .. mid)
assert(
    late > mid + 1.0,
    "and are still arriving two minutes later, which is a CURRENT and"
        .. " not a reservoir emptying: " .. mid .. " -> " .. late
)
local room_late = room_kpa()
assert(
    room_late > PLACED_FLOOR - 2.0 and room_late < SUPPLIES_UNDER + 2.0,
    "while the room holds in the band between the floor and the vent's"
        .. " release line: " .. room_early .. " -> " .. room_late .. " kPa"
)
assert(
    t.structure_at(2, 1).state == "scrubbing",
    "and the grille is still an ordinary running scrubber throughout"
)

-- ---------------------------------------------------------------
-- THE SIPHON IGNORES THE FLOOR, WHICH IS WHY IT IS STILL THE
-- EMERGENCY.
--
-- The floor is a property of the SCRUBBING position. Turn the same
-- machine round and it empties the room, because that is the job:
-- a plasma flood, a fire, a chamber you want empty before you open it.
-- A siphon that stopped at a hundred kilopascals would be a siphon
-- that cannot do the one thing it is for.
-- ---------------------------------------------------------------
local PURGE = string.gsub(
    DEAD_SUPPLY,
    '%(2, 1, "air_scrubber", "scrubbing"%)',
    '(2, 1, "air_scrubber", "siphoning")'
)
t.world(PURGE, 7)
t.set_environment({ sink_k = 293.15, insolation = 0 })
t.tick()

local purging = t.structure_at(2, 1)
assert(purging.state == "siphoning", "turned round from the moment it is bolted down")
assert(
    string.find(purging.sprite, "purge") ~= nil,
    "and drawn as the thing it is, from the corridor: " .. purging.sprite
)

local before_purge = room_kpa()
assert(before_purge > 90.0, "the room opens breathable: " .. before_purge)
t.run_seconds(600)
local purged = room_kpa()
assert(
    purged < 20.0,
    "a siphon takes a room past a floor it does not have: "
        .. before_purge .. " -> " .. purged .. " kPa"
)

-- ---------------------------------------------------------------
-- A NAMED ROSTER STOPS AT THE FLOOR TOO, AND THE FLOOR IS THAT
-- SELECTION'S OWN PARTIAL PRESSURE.
--
-- The stop rule is one rule, read against whatever the roster selects.
-- On the whole-air roster that is the room's pressure; on a named one
-- it is Dalton's sum over the gases named, and the breathable air the
-- machine is NOT selecting is no part of the question. So a scrubber
-- pointed at carbon dioxide with a floor of ten kilopascals takes the
-- room's carbon dioxide down to ten kilopascals of carbon dioxide, in
-- a room sitting at a whole atmosphere, and leaves the atmosphere
-- alone.
-- ---------------------------------------------------------------
local NAMED = [==[(
    name: "named roster, floor over zero",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#....ag#",
        "########",
    ],
    spawns: [(5, 2)],
    pipes: [(0, 1, 2), (1, 1, 2)],
    // Sieving rather than returning, dial wide open, and a floor over
    // zero -- which is the one combination neither other file has.
    structures: [
        (2, 1, "air_scrubber", "scrubbing",
            { "whole_air": false, "rate_lps": 200.0, "floor_kpa": 10.0 }),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==]

t.world(NAMED, 7)
t.set_environment({ sink_k = 293.15, insolation = 0 })
t.tick()

local air_0 = room_moles("o2") + room_moles("n2")
for _, tile in ipairs(ROOM) do
    assert(t.foul_room(tile[1], tile[2], "co2", 10.0), "the crew have been breathing")
end
t.tick()
local co2_0 = room_kpa("co2")
assert(co2_0 > 20.0, "well over the floor to start with: " .. co2_0 .. " kPa of it")

t.run_seconds(240)
local co2_1 = room_kpa("co2")
near(co2_1, 10.0, 1.0, "the carbon dioxide came down to the floor and stopped")
assert(
    room_kpa() > 90.0,
    "in a room still holding an atmosphere, because the floor is read"
        .. " against the SELECTION and not against the room: "
        .. room_kpa() .. " kPa"
)
near(
    room_moles("o2") + room_moles("n2"),
    air_0,
    0.5,
    "and not a mole of the breathable air was touched"
)

t.run_seconds(240)
near(room_kpa("co2"), co2_1, 0.5, "four more minutes and it has not moved")
