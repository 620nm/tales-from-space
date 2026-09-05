-- The temperature control unit: the machine that makes a pipe colder
-- than everything around it, and hotter, off the same dial.
--
-- ENERGY IS NOT THE ASSERTION HERE, and that is the one way this
-- machine differs from every other thermal device in the kit
-- (thermal_devices_test.luau weighs `pipe_energy` on all three of
-- those, because a pump and a plate pair only ever MOVE heat). This one
-- is a virtual heat bath: joules enter and leave the gas by design, and
-- what the station pays for them is watts. So what is assertable is the
-- shape of the approach -- monotone towards the dial, and an arrest ON
-- the dial rather than an overshoot past it -- plus the two ways it can
-- be made to stop.
--
-- tg's arithmetic, once (thermomachine.dm:166-198):
--   Q = CALCULATE_CONDUCTION_ENERGY(target - T_port, C_port, C_machine)
-- which closes a fixed fraction C_machine/(C_port + C_machine) of the
-- remaining gap every pass. With 5000 J/K of thermostat against a short
-- run that fraction is most of it, so these scenarios settle in
-- seconds, exactly as tg's do on a pipe this size.

local T20C = 293.15

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if word(r.label) == label then
            return word(r.value)
        end
    end
    return nil
end

-- One atmos pass: the machine works its port once every half second
-- (SSair's cadence), so a spec that wants to watch the approach steps
-- in passes rather than in ticks.
local function pass()
    t.run_ticks(10)
end

local ROWS = [==[
    rows: [
        "########",
        "#......#",
        "#a....g#",
        "########",
    ],
    spawns: [(3, 2)],
    pipes: [(1, 1, 4), (2, 1, 4)],
    structures: [(3, 1, "thermomachine")],
]==]

t.world(
    [==[(
    name: "cold room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
]==] .. ROWS .. ")",
    7
)

local p = t.join()
t.tick()

assert(t.structure_at(3, 1).id == "thermomachine", "a unit stands on the line")
assert(t.structure_at(3, 1).state == "off", "off out of the crate")
near(t.pipe_temperature(1, 1), T20C, 0.5, "and the run it is plumbed into opens at room temperature")

-- ---------------------------------------------------------------
-- THE PANEL, AND THE RANGE ITS PARTS GIVE IT.
--
-- tg computes both ends in `RefreshParts` from the tiers of what is
-- inside (thermomachine.dm:95-96): 73.15 K and 573.15 K on the tier-1
-- lasers this pack's board asks for. The panel publishes exactly the
-- pair the server clamps to, so no setting can be dialled that the
-- machine will not honour.
-- ---------------------------------------------------------------
t.click(p, 3, 1, t.target_at(3, 1, "thermomachine"))
t.tick()
local panel = t.ui(p)
assert(panel, "a temperature control unit wears its own panel")
assert(panel.setpoints[1].field == "temperature", "with a thermostat on it")
assert(panel.setpoints[1].unit == "K")
near(panel.setpoints[1].value, T20C, 0.01, "tg's T20C out of the crate")
near(panel.setpoints[1].min, 73.15, 0.01, "two tier-1 lasers at the cold end")
near(panel.setpoints[1].max, 573.15, 0.01, "and at the hot end")
near(t.pipe_pressure(1, 1), tonumber(readout(panel, "thermo.pressure"):match("[%d%.]+")), 0.2,
    "the panel reads the run it is actually plumbed into")

-- ---- the dial cannot be asked for more than the parts can give ----
t.ui_act(p, "set", '{"field":"temperature","value":50}')
t.tick()
near(t.ui(p).setpoints[1].value, 73.15, 0.01, "a colder setting is clamped to the machine's floor")
t.ui_act(p, "set", '{"field":"temperature","value":900}')
t.tick()
near(t.ui(p).setpoints[1].value, 573.15, 0.01, "and a hotter one to its ceiling")

-- ---------------------------------------------------------------
-- HEATING: monotone towards the dial, and an ARREST on it.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"temperature","value":400}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "running", "the unit is running")

local moles_0 = t.pipe_gas(1, 1).n2
local previous = t.pipe_temperature(1, 1)
for _ = 1, 12 do
    pass()
    local now = t.pipe_temperature(1, 1)
    assert(now >= previous - 0.01, "the approach never runs backwards: " .. previous .. " -> " .. now)
    assert(now <= 400.0 + 0.01, "and never overshoots the dial: " .. now)
    previous = now
end
near(t.pipe_temperature(1, 1), 400.0, 0.5, "it arrests on the setpoint")

-- Long after it has arrived, it is still sitting there. A machine that
-- kept adding heat would have run away by now.
t.run_seconds(60)
near(t.pipe_temperature(1, 1), 400.0, 0.5, "and holds there for as long as you like")

-- NOT ONE MOLE. It conditions the gas standing in its mouth; it does
-- not move any. The pressure rose because the gas got hotter, which is
-- the gas law and not a transfer.
near(t.pipe_gas(1, 1).n2, moles_0, moles_0 * 0.0001, "no gas entered or left the run")
assert(t.pipe_pressure(1, 1) > 101.0, "and the hotter gas pushes harder: " .. t.pipe_pressure(1, 1))

-- The panel tracks the run live rather than reporting the moment it
-- was opened.
t.click(p, 3, 1, t.target_at(3, 1, "thermomachine"))
t.tick()
near(
    tonumber(word(t.ui(p).readouts[1].value):match("[%d%.]+")),
    t.pipe_temperature(1, 1),
    0.5,
    "the thermometer on the panel is the run's own"
)

-- ---------------------------------------------------------------
-- COOLING, and being switched off MID-JOB.
--
-- The same dial, the other way: 400 K gas driven down to 150. Then the
-- switch, and the books freeze exactly where they were -- tg's
-- `process_atmos` opens with `if(!on) return` (thermomachine.dm:167).
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"temperature","value":150}')
pass()
local cooling = t.pipe_temperature(1, 1)
assert(cooling < 400.0 - 5.0, "the same machine cools: 400 -> " .. cooling)

t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "off", "switched off mid-job")
local frozen = t.pipe_temperature(1, 1)
t.run_seconds(30)
near(t.pipe_temperature(1, 1), frozen, 0.5, "and the gas is left exactly where it was")

-- ---------------------------------------------------------------
-- A DEAD GRID IS THE SAME ANSWER, ASKED IN BOTH PLACES.
--
-- tg's `on && is_operational` picks the picture AND gates the work
-- (thermomachine.dm:122, 172-174). The same room with nobody's cable
-- under it: an unwired map is an unpowered map, which is the station
-- this machine is absent from.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "dark cold room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
]==] .. ROWS .. ")",
    7
)

local d = t.join()
t.tick()
t.run_seconds(3)
local dead_0 = t.pipe_temperature(1, 1)

t.click(d, 3, 1, t.target_at(3, 1, "thermomachine"))
t.tick()
assert(readout(t.ui(d), "thermo.supply") == "thermo.supply.dead",
    "the panel says the mains are not behind it")
t.ui_act(d, "set", '{"field":"temperature","value":500}')
t.ui_act(d, "toggle", '{"field":"power"}')
t.run_seconds(30)

assert(t.ui(d).toggles[1].on == true, "the switch is on")
assert(
    t.structure_at(3, 1).state == "off",
    "and the machine is still drawn dead, which is tg's `on && is_operational`"
        .. " picking the picture"
)
near(t.pipe_temperature(1, 1), dead_0, 0.5, "an unpowered unit conditions nothing")
