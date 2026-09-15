local network_matter = require("@helpers/network_matter")
local ui_controls = require("@helpers/ui_controls")

-- The three machines that care how HOT the gas is.
--
-- Everything else in the atmospherics kit sorts by pressure (the pumps
-- and gates) or by which gas it is (the filter). These three ask about
-- temperature, and between them they are the whole of station cooling:
-- a gate that only lets cold gas past, a pump that moves heat and not
-- one mole of gas, and a pair of plates that dump one loop's heat into
-- another without the two ever mixing.
--
-- ENERGY IS WHAT IS BEING ASSERTED HERE, not temperature. A machine
-- that warmed a pipe by exactly the right number of degrees while
-- quietly minting the joules would read perfectly on a thermometer, so
-- every heat transfer below is weighed on `network_matter.energy` -- the
-- conserved quantity -- as well as on `network_matter.temperature`. tg's own
-- temperature pump would fail that at the bottom of the range: it
-- floors both sides at TCMB independently, crediting the output for
-- heat the input never gave up.

-- Standard air, the temperature every mapped run opens the shift at
-- (lunatic_matter::T20C).
local T20C = 293.15
-- tg's T0C: where a temperature gate's dial sits out of the crate
-- (temperature_gate.dm:10). Note it is BELOW room temperature -- that
-- is the whole shape of the first scenario.
local T0C = 273.15

local PIPE_M3 = 0.070
local PORT_M3 = 0.200

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local word = ui_controls.word

local function net_m3(lengths: number, ports: number)
    return lengths * PIPE_M3 + ports * PORT_M3
end

local function moles(kpa: number, m3: number)
    return kpa * 1000.0 * m3 / (8.314 * T20C)
end

local function near(a: number, b: number, slack: number, what: string)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function readout(value: unknown, label: string): string
    local panel = ui_controls.record(value)
    for _, r in ipairs(ui_controls.rows(panel.readouts)) do
        if word(r.label) == label then
            return word(r.value)
        end
    end
    error("missing readout: " .. label)
end

-- One step plus the move cooldown, so two calls in a row are two steps.
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- The map every gate scenario below uses: a charged supply west of the
-- gate, one lonely mapped length east of it, and a coil of pipe in
-- reach. Two fresh lengths onto the delivery side dilute it well under
-- the supply, which is the head the gate is then given the chance to
-- pass or refuse.
local GATE_MAP = [==[(
    name: "temperature gate",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'a': (composition: (components: [(component: "station_base")]), fixture: Some(Apc)),
        'g': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
    },
    rows: [
        "##########",
        "#........#",
        "#..a....g#",
        "##########",
    ],
    items: [(5, 2, "pipe"), (3, 2, "multitool")],
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 4, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
    structures: [(5, 2, "player_spawn"), (3, 1, "temperature_gate")],

)]==]

local SUPPLY_M3 = net_m3(2, 1)
local DELIVERY_M3 = net_m3(3, 1)

-- Lay the two fresh lengths, put the coil down, and walk back to the
-- gate. Returns the two pressures the scenario starts from.
local function charge_gate_map(p)
    t.click(p, 5, 2, t.target_at(p, 5, 2, "pipe"))
    t.run_ticks(2)
    for _, x in ipairs({ 5, 6 }) do
        t.click(p, x, 1)
        t.run_seconds(1.5)
    end
    t.drop(p)
    t.run_ticks(2)
    walk(p, "west")
    walk(p, "west")

    local supply = assert(network_matter.pressure(1, 1))
    local delivery = assert(network_matter.pressure(6, 1))
    assert(supply > 90.0, "the supply is charged: " .. supply)
    assert(
        delivery < supply - 20.0,
        "and the delivery main, diluted by two fresh lengths, is well" .. " under it: " .. delivery
    )
    return supply, delivery
end

-- ---------------------------------------------------------------
-- WARM GAS DOES NOT GET PAST A GATE SET TO FREEZING.
--
-- No heater is needed to show this, because tg's default setpoint is
-- already on the interesting side of the line: a gate ships set to T0C
-- (273.15 K) and a mapped run opens the shift at T20C (293.15 K). So a
-- freshly armed gate with head to spare passes NOTHING -- the gas in
-- front of it is twenty degrees too warm.
--
-- Then a multitool on the sensor (temperature_gate.dm:137-145) reverses
-- the test, and the same gate, at the same setting, with the same gas
-- in front of it, opens. Nothing about the machine changed but which
-- way round it reads.
-- ---------------------------------------------------------------
t.world(GATE_MAP, 7)

local p = t.join()
t.tick()

assert(assert(t.structure_at(3, 1)).id == "temperature_gate", "the map stood one there")
assert(assert(t.structure_at(3, 1)).state == "shut", "and tg's ships shut")
near(assert(network_matter.temperature(1, 1)), T20C, 0.5, "a mapped run opens at room temperature")

local supply_0, delivery_0 = charge_gate_map(p)
local books = moles(supply_0, SUPPLY_M3) + moles(delivery_0, DELIVERY_M3)

t.click(p, 3, 1, t.target_at(p, 3, 1, "temperature_gate"))
t.tick()
local panel = ui_controls.record(assert(t.ui(p), "a temperature gate wears the shared flow panel"))
local setpoint = ui_controls.rows(panel.setpoints)[1]
assert(setpoint.field == "temperature", "with a thermometer on it")
assert(setpoint.unit == "K")
near(ui_controls.number(setpoint.value), T0C, 0.01, "tg's T0C out of the crate")
near(ui_controls.number(setpoint.max), 4500.0, 0.01, "tg's max_temperature")
assert(ui_controls.number(setpoint.min) < 3.0, "and its floor is TCMB, not zero")
assert(
    readout(panel, "flow.sensor") == "flow.sensor.normal",
    "the panel says which way round it reads, which tg hides on examine"
)

ui_controls.toggle(p, "power")
t.run_ticks(2)
assert(assert(t.structure_at(3, 1)).state == "armed", "the gate is armed")

t.run_seconds(30)
near(assert(network_matter.pressure(6, 1)), delivery_0, 0.5, "nothing crossed: the gas is too warm")
near(assert(network_matter.pressure(1, 1)), supply_0, 0.5, "and the supply is untouched")

-- ---- a multitool on the sensor, and the test reverses ----
t.click(p, 3, 2, t.target_at(p, 3, 2, "multitool"))
t.run_ticks(2)
assert(t.hands(p).held == "multitool", "multitool in hand")
local _ = t.messages(p)
t.click(p, 3, 1, t.target_at(p, 3, 1, "temperature_gate"))
t.run_ticks(2)
assert(
    said(
        p,
        "You reverse the temperature gate's sensor. It will pass gas that"
            .. " is HOTTER than its setting."
    ),
    "the tool says which way round the gate now reads"
)
assert(
    t.ledger_has("MachineToggled", "invert", "Player"),
    "and reversing a gate's sensor is an attributed act"
)

t.run_seconds(60)
local inverted_out = assert(network_matter.pressure(6, 1))
assert(
    inverted_out > delivery_0 + 10.0,
    "inverted, the same warm gas passes: " .. delivery_0 .. " -> " .. inverted_out
)
assert(assert(network_matter.pressure(1, 1)) < supply_0, "and the supply is what paid for it")
local after = moles(assert(network_matter.pressure(1, 1)), SUPPLY_M3) + moles(inverted_out, DELIVERY_M3)
assert(
    math.abs(after - books) < books * 0.02,
    "the books balance across the gate: " .. books .. " mol -> " .. after .. " mol"
)

-- The panel says so too. A gate whose sensor is backwards and a gate
-- that is simply shut are otherwise identical from the corridor, which
-- is the one thing tg's interface cannot tell you.
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 1, t.target_at(p, 3, 1, "temperature_gate"))
t.tick()
assert(
    readout(ui_controls.state(p), "flow.sensor") == "flow.sensor.reversed",
    "and the panel says the sensor is reversed"
)

-- ---------------------------------------------------------------
-- COLD GAS PASSES.
--
-- The other half of the same sentence, on a fresh gate with a fresh
-- head: leave the sensor alone and wind the SETTING up over the gas.
-- 293 K air is now the cold side of 400 K, and it flows.
-- ---------------------------------------------------------------
t.world(GATE_MAP, 7)

local c = t.join()
t.tick()
local cold_supply_0, cold_delivery_0 = charge_gate_map(c)
local cold_books = moles(cold_supply_0, SUPPLY_M3) + moles(cold_delivery_0, DELIVERY_M3)

t.click(c, 3, 1, t.target_at(c, 3, 1, "temperature_gate"))
t.tick()
ui_controls.set(c, "temperature", 400)
ui_controls.toggle(c, "power")
t.run_seconds(60)

local cold_out = assert(network_matter.pressure(6, 1))
assert(
    cold_out > cold_delivery_0 + 10.0,
    "under the setting, the gas is 'cold' and flows: " .. cold_delivery_0 .. " -> " .. cold_out
)
assert(
    cold_out < cold_supply_0,
    "and it stopped short of the supply -- a gate releases towards its"
        .. " own input pressure and never past level: "
        .. cold_out
)
local cold_after = moles(assert(network_matter.pressure(1, 1)), SUPPLY_M3) + moles(cold_out, DELIVERY_M3)
assert(
    math.abs(cold_after - cold_books) < cold_books * 0.02,
    "and these books balance too: " .. cold_books .. " -> " .. cold_after
)

-- ---------------------------------------------------------------
-- A TEMPERATURE PUMP MOVES HEAT AND NOT ONE MOLE.
--
-- The machine a freezer loop is built out of, and the one whose whole
-- point is invisible on a pressure gauge: its two sides stay as
-- separate as a shut valve leaves them, and what crosses is energy.
--
-- Nothing a player can reach makes one pipe hotter than another yet --
-- the burn chamber and the thermomachine are still ahead -- so the
-- gradient is set up with `network_matter.heat`, which is scaffolding and
-- says so.
-- ---------------------------------------------------------------
local PUMP_NETWORKS = [==[
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 4, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
]==]

local PUMP_ROWS = [==[
    rows: [
        "#########",
        "#.......#",
        "#a.....g#",
        "#########",
    ],
    structures: [(3, 2, "player_spawn"), (3, 1, "temperature_pump")],
]==]

t.world([==[(
    name: "heat pump",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'a': (composition: (components: [(component: "station_base")]), fixture: Some(Apc)),
        'g': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
    },
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
]==] .. PUMP_NETWORKS .. [==[
    ],
]==] .. PUMP_ROWS .. ")", 7)

local q = t.join()
t.tick()
assert(assert(t.structure_at(3, 1)).id == "temperature_pump", "a heat pump")
assert(assert(t.structure_at(3, 1)).state == "off", "off out of the crate")

network_matter.heat(1, 1, 40000.0)
t.tick()
local hot_0 = assert(network_matter.temperature(1, 1))
local cold_0 = assert(network_matter.temperature(5, 1))
assert(hot_0 > cold_0 + 50.0, "the input side is hot: " .. hot_0 .. " vs " .. cold_0)

local energy_0 = assert(network_matter.energy(1, 1)) + assert(network_matter.energy(5, 1))
local hot_moles_0 = assert(network_matter.gas(1, 1)).n2
local cold_moles_0 = assert(network_matter.gas(5, 1)).n2
assert(hot_moles_0 > 0.0 and cold_moles_0 > 0.0, "both sides hold gas")

t.click(q, 3, 1, t.target_at(q, 3, 1, "temperature_pump"))
t.tick()
local pump_panel = ui_controls.record(assert(t.ui(q), "panel opens"))
local throttle = ui_controls.rows(pump_panel.setpoints)[1]
assert(throttle.field == "share", "the pump's dial is a throttle")
assert(throttle.unit == "%")
near(ui_controls.number(throttle.value), 0.0, 0.01, "and tg ships it shut at zero")

-- ---- switched on with the throttle shut: still nothing ----
--
-- tg's `heat_transfer_rate = 0` (temperature_pump.dm:11) is a real trap
-- and is kept: a pump somebody has only switched on does nothing at
-- all, forever.
ui_controls.toggle(q, "power")
t.run_seconds(20)
assert(assert(t.structure_at(3, 1)).state == "running", "the pump is running")
near(
    assert(network_matter.temperature(1, 1)),
    hot_0,
    0.5,
    "and moving no heat, because its throttle is shut"
)

-- ---- open the throttle ----
ui_controls.set(q, "share", 100)
t.run_seconds(30)
local hot_1 = assert(network_matter.temperature(1, 1))
local cold_1 = assert(network_matter.temperature(5, 1))
assert(hot_1 < hot_0 - 5.0, "the input got cooler: " .. hot_0 .. " -> " .. hot_1)
assert(cold_1 > cold_0 + 5.0, "and the output hotter: " .. cold_0 .. " -> " .. cold_1)

-- NOT ONE MOLE. The assertion the machine exists for, and the one a
-- pressure gauge would never catch on its own.
near(assert(network_matter.gas(1, 1)).n2, hot_moles_0, hot_moles_0 * 0.0001, "no moles left the input")
near(
    assert(network_matter.gas(5, 1)).n2,
    cold_moles_0,
    cold_moles_0 * 0.0001,
    "and none arrived at the output"
)

-- And the books: every joule the output gained came off the input.
local energy_1 = assert(network_matter.energy(1, 1)) + assert(network_matter.energy(5, 1))
near(energy_1, energy_0, 1.0, "thermal energy is conserved across the pump")

-- ---- and it never pushes uphill ----
--
-- tg acts only while the input is the warmer side
-- (temperature_pump.dm:61). It is a throttled conductor, not a
-- refrigerator: run it as long as you like and the two converge and
-- stop, and no setting carries it past level.
t.run_seconds(240)
local hot_2 = assert(network_matter.temperature(1, 1))
local cold_2 = assert(network_matter.temperature(5, 1))
assert(hot_2 >= cold_2 - 0.5, "it approaches level and stops: " .. hot_2 .. " vs " .. cold_2)
near(
    assert(network_matter.energy(1, 1)) + assert(network_matter.energy(5, 1)),
    energy_0,
    1.0,
    "and the books still balance at the end of it"
)

-- ---- a dead pump moves nothing ----
--
-- The same room and the same panel, with nobody's cable under any of
-- it: an unwired map is an unpowered map, so the pump has a switch and
-- no mains behind it.
t.world([==[(
    name: "dead heat pump",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'a': (composition: (components: [(component: "station_base")]), fixture: Some(Apc)),
        'g': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
    },
    networks: [
]==] .. PUMP_NETWORKS .. [==[
    ],
]==] .. PUMP_ROWS .. ")", 7)

local d = t.join()
t.tick()
t.run_seconds(3)
network_matter.heat(1, 1, 40000.0)
t.tick()
local dead_hot = assert(network_matter.temperature(1, 1))
local dead_cold = assert(network_matter.temperature(5, 1))

t.click(d, 3, 1, t.target_at(d, 3, 1, "temperature_pump"))
t.tick()
assert(
    readout(ui_controls.state(d), "flow.supply") == "flow.supply.dead",
    "the panel says the mains are not behind it"
)
ui_controls.set(d, "share", 100)
ui_controls.toggle(d, "power")
t.run_seconds(60)
assert(ui_controls.rows(ui_controls.state(d).toggles)[1].on == true, "the switch is on")
assert(
    assert(t.structure_at(3, 1)).state == "off",
    "and the machine is still drawn dead, which is tg's `on &&"
        .. " is_operational` picking the picture"
)
near(assert(network_matter.temperature(1, 1)), dead_hot, 0.5, "an unpowered heat pump moves nothing")
near(assert(network_matter.temperature(5, 1)), dead_cold, 0.5, "in either direction")

-- ---------------------------------------------------------------
-- A PLATE HEAT EXCHANGER IS HALF A MACHINE.
--
-- One plate does nothing at all. Two of them face to face across a tile
-- boundary equalise the runs behind them completely -- every tick, no
-- dial, no power, no switch. The two bodies of gas never mix, which is
-- what lets a plasma loop be cooled against a nitrogen one.
--
-- Both cases stand in one room below. The pair at (3,1)/(4,1) look at
-- each other; the lone plate at (9,1) looks at bare deck. Each plate's
-- own run reaches away from its face, because a unary's mouth is BEHIND
-- it (unary_devices.dm:14).
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "plates",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "##############",
        "#............#",
        "#............#",
        "##############",
    ],
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 6, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 10, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 11, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
    structures: [
        (6, 2, "player_spawn"),
        (3, 1, "heat_exchanger"),
        (4, 1, "heat_exchanger"),
        (9, 1, "heat_exchanger"),
    ],
)]==],
    7
)

local _r = t.join()
t.tick()

assert(assert(t.structure_at(3, 1)).id == "heat_exchanger", "two plates meet on the seam")
assert(assert(t.structure_at(4, 1)).id == "heat_exchanger")
assert(assert(t.structure_at(9, 1)).id == "heat_exchanger", "and one stands on its own")

near(assert(network_matter.temperature(1, 1)), T20C, 0.5, "every run opens at room temperature")
near(assert(network_matter.temperature(6, 1)), T20C, 0.5, "the far side of the pair too")
near(assert(network_matter.temperature(11, 1)), T20C, 0.5, "and the lone plate's own run")

-- Heat one side of the pair, and the lone plate's run by the same
-- amount, so the two cases are compared like for like.
network_matter.heat(1, 1, 30000.0)
network_matter.heat(11, 1, 30000.0)
t.tick()
local pair_energy_0 = assert(network_matter.energy(1, 1)) + assert(network_matter.energy(6, 1))
local lone_energy_0 = assert(network_matter.energy(11, 1))
local hot_side_0 = assert(network_matter.temperature(1, 1))
local lone_hot_0 = assert(network_matter.temperature(11, 1))
assert(hot_side_0 > T20C + 50.0, "one side of the pair is hot: " .. hot_side_0)
near(lone_hot_0, hot_side_0, 1.0, "and the lone plate's run is heated the same")

t.run_seconds(10)

-- ---- the pair: complete equalisation, and quickly ----
local settled_a = assert(network_matter.temperature(1, 1))
local settled_b = assert(network_matter.temperature(6, 1))
near(settled_a, settled_b, 0.5, "two facing plates equalise the runs behind them")
assert(
    settled_a < hot_side_0 - 20.0,
    "the hot side came down: " .. hot_side_0 .. " -> " .. settled_a
)
assert(settled_b > T20C + 5.0, "and the cold side came up: " .. settled_b)
near(
    assert(network_matter.energy(1, 1)) + assert(network_matter.energy(6, 1)),
    pair_energy_0,
    1.0,
    "and not a joule was made or lost doing it"
)

-- The gas did NOT mix, which is the whole reason to plumb two loops
-- through plates rather than through a valve.
assert(network_matter.pressure(1, 1) ~= nil and network_matter.pressure(6, 1) ~= nil, "both runs still exist")

-- ---- the lone plate: nothing, for as long as you like ----
--
-- tg's `atmos_init` finds no partner and gives up quietly
-- (heat_exchanger.dm:52-55). A single plate is not broken; it is half
-- of a machine.
near(assert(network_matter.temperature(11, 1)), lone_hot_0, 1.0, "a plate with nobody to face does nothing")
near(assert(network_matter.energy(11, 1)), lone_energy_0, 1.0, "and keeps every joule it was given")

-- ---------------------------------------------------------------
-- THE ROUND TRIP, and the refusal each of the three carries.
--
-- The universal atmospherics construction: you never place a machine,
-- you place a FITTING and wrench it, and unwrenching mints the fitting
-- back (fittings_test.luau says why at length). What is device-specific
-- is the GUARD -- the gate and the pump both refuse to come up while
-- they are running, and the plate has nothing to be running.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "thermal fittings",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'a': (composition: (components: [(component: "station_base")]), fixture: Some(Apc)),
        'g': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
    },
    rows: [
        "##########",
        "#........#",
        "#..a....g#",
        "##########",
    ],
    items: [
        (3, 2, "wrench"),
        (6, 2, "temperature_gate_fitting"),
        (7, 2, "heat_exchanger_fitting"),
    ],
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 4, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 5, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
    structures: [(3, 2, "player_spawn"), (3, 1, "temperature_pump")],

)]==],
    7
)

local s = t.join()
t.tick()

-- The switch is thrown BARE-HANDED, because a wrench in the working
-- hand is not an interface -- it is the wrench, and a click carrying
-- one means the transition. So: switch first, tool second, throughout.
local function throw_pump_switch(want: string)
    t.click(s, 3, 1, t.target_at(s, 3, 1, "temperature_pump"))
    t.tick()
    ui_controls.toggle(s, "power")
    t.run_ticks(2)
    t.ui_close(s)
    t.tick()
    assert(assert(t.structure_at(3, 1)).state == want, "the pump is " .. want)
end

local function take_wrench()
    t.click(s, 3, 2, t.target_at(s, 3, 2, "wrench"))
    t.run_ticks(2)
    assert(t.hands(s).held == "wrench", "wrench in hand")
end

-- ---- a running machine is not pulled out of the line ----
throw_pump_switch("running")
take_wrench()

t.click(s, 3, 1, t.target_at(s, 3, 1, "temperature_pump"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) ~= nil, "a wrench will not take it up while it runs")
assert(assert(t.structure_at(3, 1)).state == "running", "it is still running, in fact")

-- Off, and now it comes up -- and yields its own fitting back.
t.drop(s)
t.run_ticks(2)
throw_pump_switch("off")
take_wrench()
local room_before = assert(t.room_pressure(3, 1))
t.click(s, 3, 1, t.target_at(s, 3, 1, "temperature_pump"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "off, it comes up off the deck")

-- TWO THINGS COME OFF THE LINE. The 400 L standing in the machine's
-- two ports hisses into the room it was bolted to (pipes/mod.rs: a
-- port that loses its run vents like any other severed pipe end), so
-- an engineer who unbolts a charged main gets a faceful --
assert(
    assert(t.room_pressure(3, 1)) > room_before,
    "the ports vented into the room when the machine left the run: "
        .. room_before
        .. " -> "
        .. assert(t.room_pressure(3, 1))
)
-- -- and the fitting lands on the MACHINE's tile
-- (docs/CONSTRUCTION.md), where the air it just let go of is moving,
-- which is why this counts the world rather than one tile.
assert(
    t.count_items("temperature_pump_fitting") == 1,
    "and exactly one fitting came back into the world"
)
local at_hand = false
for _, item in ipairs(t.items_at(3, 1)) do
    if item == "temperature_pump_fitting" then
        at_hand = true
    end
end
assert(at_hand, "lying on the tile the machine came off")

-- ---- you do not raise a machine on the tile you are standing on ----
walk(s, "east")
walk(s, "east")
walk(s, "east")
local _ = t.messages(s)
t.click(s, 6, 2, t.target_at(s, 6, 2, "temperature_gate_fitting"))
t.run_seconds(2.5)
assert(t.structure_at(6, 2) == nil, "a fitting under your own boots stays a fitting")
assert(said(s, "Something is in the way."), "and the refusal says why")

-- ---- and from one tile over, both of them go down ----
walk(s, "west")
for _, job in ipairs({
    { x = 6, id = "temperature_gate" },
    { x = 7, id = "heat_exchanger" },
}) do
    t.click(s, job.x, 2, t.target_at(s, job.x, 2, job.id .. "_fitting"))
    t.run_seconds(2.5)
    local built = t.structure_at(job.x, 2)
    assert(
        built ~= nil and built.id == job.id,
        "a wrenched " .. job.id .. " fitting becomes the machine"
    )
    assert(
        t.target_at(s, job.x, 2, job.id .. "_fitting") == nil,
        "and the fitting is spent rather than left lying under it"
    )
    walk(s, "east")
end
