-- The air vent's PANEL: the console tg hangs on a wall, bolted to the
-- machine instead.
--
-- vents_test.luau owns this machine's arithmetic -- what it does to a
-- room with nobody touching it -- and vent_construction_test.luau owns
-- carrying one and bolting it down. This file is the third thing, and
-- until now there was nothing to test: a vent had no control surface at
-- all, because tg's has none either. A tg vent pump carries a
-- direction, a `pressure_checks` selector and two bounds
-- (vent_pump.dm:24-30) and every one of them is written by an area's
-- AIR ALARM. There is no air alarm here, so a vent with no panel was a
-- machine nobody could set.
--
-- What the panel offers is a switch and THREE PRESSURES: the line both
-- directions work to, and the two lines of the dead band that decide
-- which direction runs. The band is also the direction control -- push
-- the high line up and the machine will never siphon, drop the low line
-- to nothing and it will never release -- which is tg's
-- `pump_direction` said in the machine's own numbers.
--
-- Every assertion below is about the same one claim: the sim reads the
-- MACHINE. Before this, `run_vents` worked every vent on the station to
-- one atmosphere off a constant in Rust, and the dials in the property
-- sheet were decoration.

local ONE_ATM = 101.325
-- The pack's own defaults (structures/vent.luau), which are the numbers
-- the whole station's air loop is tuned against.
local FEEDS_UNDER = 100.31175
local EMPTIES_OVER = 109.431

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function readout(p, label)
    for _, r in ipairs(t.ui(p).readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
end

local function toggle(p, field)
    for _, sw in ipairs(t.ui(p).toggles) do
        if sw.field == field then
            return sw
        end
    end
    return nil
end

local function dial(p, field)
    for _, row in ipairs(t.ui(p).setpoints) do
        if row.field == field then
            return row
        end
    end
    return nil
end

local function set(p, field, value)
    t.ui_act(p, "set", '{"field":"' .. field .. '","value":' .. value .. "}")
    t.run_ticks(2)
end

-- Everything in the corridor, in moles. A room that is meant to be
-- holding STILL is read on the conserved quantity and never on a
-- pressure: a compartment that has just been opened to space is also a
-- compartment that got COLD, and the deck under it warms it back up
-- over the next minute -- so its pressure climbs with nobody feeding
-- it, and the moles do not.
local function room_moles()
    local n = 0.0
    for x = 1, 7 do
        for _, amount in pairs(t.room_gas(x, 1) or {}) do
            n = n + amount
        end
    end
    return n
end

-- A sealed corridor with a vent at one end, a bottle on a connector
-- port regulated down to one atmosphere by a pump, and a real wired
-- grid behind it -- vents_test.luau's own bench, because a fan with no
-- cable under it never turns.
local BENCH = [==[(
    name: "vent panel",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'g': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
    },
    rows: [
        "#########",
        "#.....ga#",
        "#########",
    ],
    // A crewman stands ON the pump, which is where an engineer working
    // this end of the run stands: nothing in the plumbing is dense.
    spawns: [(3, 1)],
    air_presets: {
        "canister_air": (gases: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15),
    },
    structures: [
        (2, 1, "vent"),
        // Charged well past a room's worth, because this bench asks the
        // vent to hold a corridor ABOVE one atmosphere and a fan is not
        // a compressor: it will not pull its own supply line below the
        // room it is feeding (atmos_machines/vent.rs).
        (3, 1, "gas_pump", "running", { "dir": "west", "target_kpa": 900.0 }),
        (4, 1, "connector_port", { "dir": "west" }),
        (4, 1, "canister", { "air": "canister_air" }),
    ],
    // Backbone (L2) under the generator and the APC; room circuit (L1)
    // from the APC's tile west along the corridor to the vent.
    cables: [
        (6, 1, 3), (7, 1, 3),
        (5, 1, 1), (4, 1, 1), (3, 1, 1), (2, 1, 1),
    ],
)]==]

t.world(BENCH, 7)
-- An INERT SKY, as every atmospherics bench in this pack gets: a hull
-- radiating against a sink at its own temperature emits exactly what it
-- absorbs, so a corridor watched for minutes is not also bleeding heat
-- into space and reading a kilopascal light on the gauge.
t.set_environment({ sink_k = 293.15, insolation = 0 })
t.tick()

local p = t.join()
t.run_ticks(2)

-- ---------------------------------------------------------------
-- A HAND ON A VENT OPENS ITS WINDOW, AND THE WINDOW IS THE FILE'S.
--
-- The rows are what `structures/vent.luau` declares and nothing else:
-- one atmosphere to hold at, and the two lines a station's return
-- grilles are tuned against. A panel that showed anything else would be
-- a panel reading a constant instead of the machine.
-- ---------------------------------------------------------------
t.click(p, 2, 1, t.target_at(2, 1, "vent"))
t.tick()
local panel = t.ui(p)
assert(panel ~= nil, "an empty hand on a vent opens a panel")

assert(dial(p, "setpoint").unit == "kPa", "the setpoint is a pressure")
near(dial(p, "setpoint").value, ONE_ATM, 0.001, "tg's external_pressure_bound")
near(dial(p, "release").value, FEEDS_UNDER, 0.001, "the low line of the dead band")
near(dial(p, "siphon").value, EMPTIES_OVER, 0.001, "and the high one")

-- The switch, which this machine did not have before the panel did. tg
-- maps every vent on, and so does the pack.
assert(toggle(p, "power").on == true, "a vent opens the shift running")

-- The three readouts a room device wears, which are the scrubber's
-- exactly -- one helper, not two copies (sim/ui/settings/room_device.rs).
assert(readout(p, "supply") == "fed", "the mains are behind it")
assert(readout(p, "room") ~= nil, "the room it faces is on the panel")
assert(readout(p, "supply line") ~= nil, "and so is the run it draws from")

-- ---------------------------------------------------------------
-- THE THREE DIALS ARE A BAND, AND THE PANEL WILL NOT LET IT CROSS.
--
-- `feed under <= hold at <= empty over` is an invariant of the
-- mechanism, not a convention: a machine working to a number outside
-- the band it is triggered by would release and siphon in the same
-- breath. Each dial therefore publishes the other two as its bounds,
-- and a client that asks for more gets the bound.
-- ---------------------------------------------------------------
near(dial(p, "release").max, ONE_ATM, 0.001, "the low dial stops at the setpoint")
near(dial(p, "siphon").min, ONE_ATM, 0.001, "and the high dial starts there")
near(dial(p, "setpoint").min, FEEDS_UNDER, 0.001, "the setpoint stays inside the band")
near(dial(p, "setpoint").max, EMPTIES_OVER, 0.001, "at both ends")

set(p, "siphon", 50.0)
near(dial(p, "siphon").value, ONE_ATM, 0.001, "the high line cannot be pulled under the setpoint")
set(p, "release", 500.0)
near(dial(p, "release").value, ONE_ATM, 0.001, "nor the low one pushed over it")
set(p, "release", FEEDS_UNDER)
set(p, "siphon", EMPTIES_OVER)
near(dial(p, "release").value, FEEDS_UNDER, 0.001, "and both go back")
near(dial(p, "siphon").value, EMPTIES_OVER, 0.001, "where they started")

-- ---------------------------------------------------------------
-- THE SETPOINT IS THE MACHINE'S, THE SWITCH IS REAL, AND THE SIM
-- READS BOTH.
--
-- The whole point of the panel, in one bench and with no hole in the
-- hull: tune this vent to hold the corridor at a hundred and fifty
-- kilopascals -- half again what every vent on the station used to be
-- nailed to -- and it must actually do it.
--
-- The dials move in the order the band allows, which is the discipline
-- itself: the high line first, because the setpoint may not pass it;
-- then the setpoint; then the low line under it.
--
-- It is done with the fan SWITCHED OFF, which is the other half. A vent
-- had no switch at all before this window, and the sharpest thing that
-- can be said about one is that fifty kilopascals of unmet demand with
-- nine hundred standing in the line behind it moves not one mole.
-- ---------------------------------------------------------------
local TUNED = 150.0

-- A vent still has no switch on the CASING -- a room's air must not be
-- something a passer-by turns off with an empty hand. Through the panel
-- it is a press that needed reach, sight and an interactive document,
-- and it earns a ledger row naming who made it, because a room that
-- stops being fed is how people die slowly.
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(2)
assert(toggle(p, "power").on == false, "the switch is thrown")
assert(t.structure_at(2, 1).state == "off", "and the fan is drawn dead")
assert(t.ledger_has("MachineToggled"), "with the press on the record")

set(p, "siphon", 200.0)
set(p, "setpoint", TUNED)
set(p, "release", TUNED - 1.0)
near(dial(p, "setpoint").value, TUNED, 0.001, "the vent is set to a hundred and fifty")
near(dial(p, "release").value, TUNED - 1.0, 0.001, "with its low line just under")
t.ui_close(p)
t.tick()

local opening = room_moles()
assert(t.room_pressure(5, 1) < 110.0, "the corridor opens well under the new line")
t.run_seconds(60)
near(room_moles(), opening, 0.5, "a switched-off vent hands the corridor nothing")

-- ...and on, it works to the number it was GIVEN. Against the constant
-- this machine used to be nailed to it would stop at one atmosphere,
-- which is the whole of what this file catches.
t.click(p, 2, 1, t.target_at(2, 1, "vent"))
t.tick()
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(toggle(p, "power").on == true, "the fan is switched back on")
t.ui_close(p)
t.tick()

local peak = 0.0
for _ = 1, 150 do
    t.run_seconds(1)
    peak = math.max(peak, t.room_pressure(2, 1))
end
assert(
    peak <= TUNED + 0.5,
    "the fan never blew its own tile past the setpoint it was given -- the"
        .. " release arithmetic is demand-limited, so overshoot is not"
        .. " clamped away, it is unrepresentable: " .. peak .. " kPa"
)
assert(
    t.room_pressure(5, 1) > TUNED - 1.0,
    "and the corridor came up to the line it was told to hold, which is"
        .. " not one it could have reached before: " .. t.room_pressure(5, 1) .. " kPa"
)

-- It STAYS there, which is the half of "arrest" a single reading cannot
-- show: a settled room is a room the vent has no demand from.
local settled = t.room_pressure(5, 1)
t.run_seconds(60)
near(t.room_pressure(5, 1), settled, 0.5, "a minute later the room has not moved")
