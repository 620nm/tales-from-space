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

-- What a scrubber is set to out of the crate, placed or built
-- (structures/props.rs, structures/air_scrubber.luau).
local PLACED_RATE = 5.0
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
assert(shape ~= nil and shape.on == false, "sieving its named gas, whole air only over the floor")

-- Overfill the room, so there is something to come down FROM and the
-- floor is a place it stops rather than a place it started.
for _, tile in ipairs(ROOM) do
    assert(t.foul_room(tile[1], tile[2], "n2", 10.0), "gas goes into every tile")
end
t.tick()
local fouled = room_kpa()
assert(fouled > 120.0, "the room is well over its floor: " .. fouled .. " kPa")

-- Twelve minutes: five litres a second is a gentle grille, and twelve
-- cubic metres of overfill come down at that pace rather than in one.
t.run_seconds(720)
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
-- THE EMERGENCY IS THE SAME TWO DIALS: WHOLE AIR, NO FLOOR.
--
-- There is no direction switch. A map that stands a scrubber down in
-- its "siphoning" state gets that pair spelled for it -- everything,
-- to vacuum -- because a siphon that stopped at a hundred
-- kilopascals would be a siphon that cannot do the one thing it is
-- for. And the purge picture is a JUDGMENT, not the state name: the
-- deck paints it only once whole air is leaving a room below the
-- safe line, so a passer-by is warned about a fact, never about a
-- setting.
-- ---------------------------------------------------------------
local PURGE = string.gsub(
    DEAD_SUPPLY,
    '%(2, 1, "air_scrubber", "scrubbing"%)',
    '(2, 1, "air_scrubber", "siphoning", { "rate_lps": 200.0 })'
)
t.world(PURGE, 7)
t.set_environment({ sink_k = 293.15, insolation = 0 })
t.tick()

local before_purge = room_kpa()
assert(before_purge > 90.0, "the room opens breathable: " .. before_purge)
assert(
    t.structure_at(2, 1).state ~= "siphoning",
    "over comfortable air the warning is not yet earned"
)

-- Let it work. The picture flips when the air crosses the safe line,
-- while nobody touches a control.
local warned = false
for _ = 1, 120 do
    t.run_seconds(5)
    local shape = t.structure_at(2, 1)
    if shape.state == "siphoning" then
        assert(
            string.find(shape.sprite, "purge") ~= nil,
            "the judged emergency wears the purge art: " .. shape.sprite
        )
        warned = true
        break
    end
end
assert(warned, "a room being emptied earns the warning on the deck")

t.run_seconds(600)
local purged = room_kpa()
assert(
    purged < 20.0,
    "whole air with no floor takes the room toward vacuum: "
        .. before_purge .. " -> " .. purged .. " kPa"
)

-- ---------------------------------------------------------------
-- A NAMED ROSTER TAKES ITS GASES TO THE LAST MOLE, AND WHOLE AIR
-- BACK ONLY OVER THE FLOOR.
--
-- The stop rule is one rule and the floor is one number, the room's.
-- A scrubber pointed at carbon dioxide with a floor of 100 kPa takes
-- every mole of carbon dioxide out of a room sitting at a whole
-- atmosphere and more, and returns whole air besides until the room
-- is down to 100 kPa -- and then leaves the atmosphere alone, still
-- taking the carbon dioxide the crew breathe into it.
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
    // Sieving, dial wide open so the section is short, and the floor
    // the machine ships with.
    structures: [
        (2, 1, "air_scrubber", "scrubbing",
            { "whole_air": false, "rate_lps": 200.0, "floor_kpa": 100.0 }),
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
assert(
    co2_1 < co2_0 * 0.05,
    "the carbon dioxide is all but gone, floor or no floor: " .. co2_0 .. " -> " .. co2_1 .. " kPa"
)
-- Whole air stops at the floor; the carbon dioxide does not, and on a
-- bench with no vent nothing puts back what it took -- so the room
-- ends a little UNDER the floor, by about the carbon dioxide that was
-- still in it when whole air stopped. With a supply vent behind it,
-- that gap is what the vent fills.
local came_down = room_kpa()
assert(came_down <= PLACED_FLOOR + 2.0, "the room came down to the floor: " .. came_down)
assert(
    came_down > 90.0,
    "in a room still holding an atmosphere, because the floor is a"
        .. " floor: " .. came_down .. " kPa"
)
assert(
    room_moles("o2") + room_moles("n2") < air_0,
    "and the breathable air the fouling pushed over the floor went down"
        .. " the waste main with it"
)

t.run_seconds(240)
assert(room_kpa("co2") <= co2_1, "four more minutes and it has only come down")
near(room_kpa(), came_down, 1.0, "and the room has not moved")
