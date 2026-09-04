-- The rest of tg's in-line roster, by what each one does to the gas.
--
-- atmos_devices_test.luau covers the two machines that teach the shape:
-- a valve is topology, a pump moves air uphill and stops at its
-- setpoint. These four are the ones that are interesting BECAUSE they
-- are not that -- a pump with no notion of arriving, a gate that will
-- only ever run downhill, a valve that watches the wrong side of
-- itself, and a limiter you can defeat with a multitool and then
-- breathe the consequences of.

local DISTRO = 4

-- The two volumes everything here is priced in: a length of pipe is
-- tg's 70 L, a device port its 200 L component mixture.
local PIPE_M3 = 0.070
local PORT_M3 = 0.200

local function net_m3(lengths, ports)
    return lengths * PIPE_M3 + ports * PORT_M3
end

local function moles(kpa, m3)
    return kpa * 1000.0 * m3 / (8.314 * 293.15)
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- ---------------------------------------------------------------
-- A VOLUME PUMP HAS NO NOTION OF ARRIVING.
--
-- The sharpest way to say what tg's volumetric pump IS: stand one
-- beside a pressure pump, give both the same two mains at the same
-- pressure, switch both on, and watch them disagree completely.
--
-- The pump is already finished before it starts. Its setpoint is
-- one atmosphere and its output main is at one atmosphere, so the
-- delta is zero and a machine that works to a pressure has nothing to
-- do (pump.dm's `pump_gas_to`).
--
-- The volume pump never asks. It moves `transfer_rate / air1.volume` of
-- its input port every pass and keeps moving it (volume_pump.dm:90-92),
-- so it empties its own supply into a main that was already full and
-- ends with twice the pressure it started with. That is the machine you
-- transfer a tankful with, and this is why it is not simply "a pump".
-- ---------------------------------------------------------------
t.world([==[(
    name: "two pumps",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "#############",
        "#..........g#",
        "#..a........#",
        "#############",
    ],
    spawns: [(3, 2)],
    // Two mains that never touch: the pressure pump's on row 1, the
    // volumetric one's on row 2, with the x ranges disjoint so no
    // length of one is ever adjacent to a length of the other.
    pipes: [
        (1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4),
        (7, 2, 4), (8, 2, 4), (10, 2, 4), (11, 2, 4),
    ],
    structures: [(3, 1, "pump"), (9, 2, "volume_pump")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3), (8, 1, 3), (9, 1, 3), (10, 1, 3), (11, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3), (7, 2, 3), (8, 2, 3), (9, 2, 3), (10, 2, 3), (11, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

assert(t.structure_at(9, 2).id == "volume_pump", "the map stood one there")
assert(t.structure_at(9, 2).state == "off", "and tg's ships off")

local IN_M3 = net_m3(2, 1)
local OUT_M3 = net_m3(2, 1)
local pressure_in = t.pipe_pressure(1, 1)
local pressure_out = t.pipe_pressure(5, 1)
local volume_in = t.pipe_pressure(7, 2)
local volume_out = t.pipe_pressure(11, 2)
assert(pressure_in > 90.0, "all four mains open the shift charged")
assert(volume_out > 90.0)
local books = moles(volume_in, IN_M3) + moles(volume_out, OUT_M3)

-- Both on, through the panel every machine with a dial on it wears.
t.click(p, 3, 1, t.target_at(3, 1, "pump"))
t.tick()
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "running", "the pressure pump is on")

for _ = 1, 6 do
    t.move(p, "east")
    t.run_ticks(5)
end
t.click(p, 9, 2, t.target_at(9, 2, "volume_pump"))
t.tick()
local panel = t.ui(p)
assert(panel, "a volume pump wears the same panel")
assert(panel.setpoints[1].field == "rate", "with a rate knob, not a pressure one")
assert(panel.setpoints[1].unit == "L/s")
near(panel.setpoints[1].value, 200.0, 0.001, "MAX_TRANSFER_RATE out of the box")
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(9, 2).state == "running", "and it is on")

t.run_seconds(60)

-- The pressure pump: nothing, in either direction, forever. It is not
-- broken and it is not off -- it has arrived.
near(t.pipe_pressure(5, 1), pressure_out, 1.0, "a pump at its setpoint has finished")
near(t.pipe_pressure(1, 1), pressure_in, 1.0, "and takes nothing from its supply")

-- The volume pump: its supply is empty and its delivery main is at
-- twice an atmosphere, because nothing in this machine ever said stop.
assert(
    t.pipe_pressure(11, 2) > 180.0,
    "the volumetric pump kept going past one atmosphere: " .. t.pipe_pressure(11, 2)
)
assert(
    t.pipe_pressure(7, 2) < 10.0,
    "and it did it by emptying its own supply: " .. t.pipe_pressure(7, 2)
)
local after = moles(t.pipe_pressure(7, 2), IN_M3) + moles(t.pipe_pressure(11, 2), OUT_M3)
assert(
    math.abs(after - books) < books * 0.02,
    "every mole came out of the supply main, not out of nowhere: "
        .. books .. " mol -> " .. after .. " mol"
)

-- ---------------------------------------------------------------
-- THE LIMITERS, AND WHAT DEFEATING THEM COSTS.
--
-- A multitool disables the pump's pressure limits (tg's
-- `multitool_act`, volume_pump.dm:162-170) and the machine starts
-- leaking: a tenth of every parcel it moves goes into the room instead
-- of down the pipe (VOLUME_PUMP_LEAK_AMOUNT, volume_pump.dm:97-101).
--
-- The proof is the books. With the limiters engaged, everything that
-- leaves the supply main arrives in the delivery main and the two sums
-- agree. With them defeated they stop agreeing, and the difference is
-- in the room -- which is exactly the sentence an engineer standing
-- next to one needs to understand about it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "overclocked",
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
        "#...a.g#",
        "########",
    ],
    spawns: [(4, 2)],
    items: [(4, 2, "multitool")],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4), (6, 1, 4)],
    structures: [(3, 1, "volume_pump")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local q = t.join()
t.tick()
t.run_seconds(2)

local LEAK_IN_M3 = net_m3(2, 1)
local LEAK_OUT_M3 = net_m3(3, 1)
local room_before = t.room_pressure(4, 2)
local supply_before = moles(t.pipe_pressure(1, 1), LEAK_IN_M3)
local held = supply_before + moles(t.pipe_pressure(5, 1), LEAK_OUT_M3)

-- Defeat the limiters. A multitool in hand and a click on the machine:
-- tg makes this a TOOL act rather than a button on the panel, because
-- somebody has to physically get at the mechanism.
t.click(q, 4, 2, t.target_at(4, 2, "multitool"))
t.run_ticks(2)
assert(t.hands(q).held == "multitool", "the multitool is in hand")
t.click(q, 3, 1, t.target_at(3, 1, "volume_pump"))
t.run_ticks(2)
assert(
    t.ledger_has("MachineToggled", "overclock", "Player"),
    "defeating a safety interlock is an attributed act"
)

-- Now run it. (Switching it on is the panel's job, and the panel needs
-- an empty hand to open -- so put the tool down first.)
t.drop(q)
t.run_ticks(2)
t.click(q, 3, 1, t.target_at(3, 1, "volume_pump"))
t.tick()
local limits = nil
for _, r in ipairs(t.ui(q).readouts) do
    if r.label == "limiters" then
        limits = r.value
    end
end
assert(limits == "DEFEATED", "and the panel says so: " .. tostring(limits))
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_seconds(60)

local supply_after = moles(t.pipe_pressure(1, 1), LEAK_IN_M3)
local left = supply_after + moles(t.pipe_pressure(5, 1), LEAK_OUT_M3)
local moved = supply_before - supply_after
local lost = held - left
assert(moved > 1.0, "the pump moved something to leak out of: " .. moved .. " mol")
-- tg's VOLUME_PUMP_LEAK_AMOUNT is 0.1 of every parcel, and this is that
-- number measured rather than trusted: a tenth of everything that left
-- the supply main never arrived in the delivery main.
near(lost / moved, 0.1, 0.01, "a tenth of every transfer leaks")
assert(
    t.room_pressure(4, 2) > room_before,
    "and the room the pump is standing in is where it went: "
        .. room_before .. " -> " .. t.room_pressure(4, 2) .. " kPa"
)

-- ---------------------------------------------------------------
-- A PASSIVE GATE RUNS DOWNHILL AND NEVER UP.
--
-- tg's passive gate "can not transfer low pressure to higher pressure"
-- (passive_gate.dm:5), and that is not a check somewhere -- it is the
-- shape of `release_gas_to`, which never closes more than half the
-- remaining gap in one pass and refuses to open at all without ten kPa
-- of head (gas_mixture.dm:720-742).
--
-- So the gate is put between a charged main and one somebody laid by
-- hand during the shift, which starts empty. Opened, it fills the empty
-- one -- but only to where the two come level by VOLUME, never to the
-- setpoint above that, and never one kPa past its own supply.
-- ---------------------------------------------------------------
t.world([==[(
    name: "passive gate",
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
        "#a....g#",
        "########",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "pipe")],
    pipes: [(4, 1, 4), (5, 1, 4), (6, 1, 4)],
    structures: [(3, 1, "passive_gate")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local g = t.join()
t.tick()
assert(t.structure_at(3, 1).state == "shut", "a gate opens the shift shut")

-- Run the west half by hand, so the gate's back port has an EMPTY main
-- behind it... and then the charged one is on its front, which is
-- uphill. Nothing may cross.
t.click(g, 1, 2, t.target_at(1, 2, "pipe"))
t.run_ticks(2)
for _, x in ipairs({ 1, 2 }) do
    t.click(g, x, 1)
    t.run_seconds(1.5)
end
assert(t.pipe(2, 1) == DISTRO, "the west main went down")

local WEST_M3 = net_m3(2, 1)
local EAST_M3 = net_m3(3, 1)
local empty = t.pipe_pressure(2, 1)
local charged = t.pipe_pressure(5, 1)
assert(empty < 1.0, "a run you laid yourself starts empty")
assert(charged > 90.0, "the mapped one beside it did not")
local gate_books = moles(empty, WEST_M3) + moles(charged, EAST_M3)

-- Open it. The gate faces east -- back port west, front port east --
-- so its input is the EMPTY main and its output the charged one. This
-- is the uphill case, and a gate simply will not.
t.drop(g)
t.run_ticks(2)
for _ = 1, 2 do
    t.move(g, "east")
    t.run_ticks(5)
end
t.click(g, 3, 1, t.target_at(3, 1, "passive_gate"))
t.tick()
assert(t.ui(g), "a gate wears the panel")
t.ui_act(g, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "open", "the gate is open")
t.run_seconds(30)
near(t.pipe_pressure(2, 1), empty, 0.5, "an open gate pointed uphill moves nothing")
near(t.pipe_pressure(5, 1), charged, 0.5, "and its supply never notices")

-- ---------------------------------------------------------------
-- ...AND DOWNHILL, IT STOPS AT LEVEL.
--
-- The same machine the other way round. The charged main is now behind
-- it, so gas runs through -- and stops where the two mains come level
-- by volume, which is BELOW the gate's own setpoint of one atmosphere.
-- A gate is not a pump: the setpoint is a ceiling it may never reach,
-- not a promise.
-- ---------------------------------------------------------------
t.world([==[(
    name: "downhill gate",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'g': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
    },
    rows: [
        "########",
        "#.....g#",
        "#.....a#",
        "########",
    ],
    spawns: [(6, 2)],
    items: [(6, 2, "pipe")],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4)],
    structures: [(3, 1, "passive_gate")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local d = t.join()
t.tick()
t.click(d, 6, 2, t.target_at(6, 2, "pipe"))
t.run_ticks(2)
for _, x in ipairs({ 5, 6 }) do
    t.click(d, x, 1)
    t.run_seconds(1.5)
end

local SUPPLY_M3 = net_m3(2, 1)
local DELIVERY_M3 = net_m3(3, 1)
local supply = t.pipe_pressure(1, 1)
local delivery = t.pipe_pressure(5, 1)
assert(supply > 90.0, "the supply main is the charged one: " .. supply)
assert(
    delivery < supply - 20.0,
    "and the delivery main, diluted by the pipe just laid onto it, is"
        .. " well below it: " .. delivery
)
local downhill_books = moles(supply, SUPPLY_M3) + moles(delivery, DELIVERY_M3)
-- Where the two would sit if they simply became one body of gas: the
-- mark a gate approaches and, because of the ten kPa it needs to open
-- at all, stops a little short of.
local level = downhill_books / (SUPPLY_M3 + DELIVERY_M3) * (8.314 * 293.15) / 1000.0

-- Hands empty to open a panel, exactly as they must be to turn a
-- wheel: a coil of pipe in your hand means you are laying pipe.
t.drop(d)
t.run_ticks(2)
for _ = 1, 2 do
    t.move(d, "west")
    t.run_ticks(5)
end
t.click(d, 3, 1, t.target_at(3, 1, "passive_gate"))
t.tick()
t.ui_act(d, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "open", "the gate is open")
t.run_seconds(60)

local settled_out = t.pipe_pressure(5, 1)
local settled_in = t.pipe_pressure(1, 1)
assert(settled_out > delivery + 10.0, "gas ran downhill through the gate: " .. settled_out)
assert(
    settled_out <= settled_in + 0.001,
    "and never once got above its own supply, which is the whole of"
        .. " 'can not transfer low pressure to higher pressure': "
        .. settled_in .. " / " .. settled_out
)
-- It stops ON level, which is tg's rule read carefully: half the
-- pressure gap across two EQUAL 200 L ports is exactly the amount that
-- levels them, so tg's gate lands on level in one pass too. Here the
-- two sides are whole pipenets of different sizes and the levelling
-- amount is what the arithmetic is written in (see release.rs).
near(settled_out, level, 1.0, "the two mains came level")
near(settled_in, level, 1.0, "from both sides at once")
assert(
    settled_out < 101.325,
    "and stopped BELOW the gate's own setpoint: a target is a ceiling"
        .. " here, never a promise: " .. settled_out
)
local downhill_after = moles(settled_in, SUPPLY_M3) + moles(settled_out, DELIVERY_M3)
assert(
    math.abs(downhill_after - downhill_books) < downhill_books * 0.02,
    "and the books balance across the gate: "
        .. downhill_books .. " mol -> " .. downhill_after .. " mol"
)
assert(gate_books > 0.0, "the uphill books were readable too")

-- ---------------------------------------------------------------
-- A PRESSURE VALVE WATCHES THE SIDE IT IS NOT FEEDING.
--
-- The gate above tests its OUTPUT and holds a line at a pressure. This
-- tests its INPUT and does nothing at all until something upstream
-- goes over the setpoint (pressure_valve.dm:181-186), which makes it a
-- relief valve: you plumb one out of a chamber that might let go.
--
-- Armed above the supply's pressure it is inert -- for as long as you
-- like. Wind the trip pressure down under it from the panel and the
-- same valve, in the same position, starts passing gas.
-- ---------------------------------------------------------------
t.world([==[(
    name: "relief",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'g': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
    },
    rows: [
        "########",
        "#.....g#",
        "#.....a#",
        "########",
    ],
    spawns: [(6, 2)],
    items: [(6, 2, "pipe")],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4)],
    structures: [(3, 1, "pressure_valve")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local v = t.join()
t.tick()
t.click(v, 6, 2, t.target_at(6, 2, "pipe"))
t.run_ticks(2)
for _, x in ipairs({ 5, 6 }) do
    t.click(v, x, 1)
    t.run_seconds(1.5)
end
t.drop(v)
t.run_ticks(2)
for _ = 1, 2 do
    t.move(v, "west")
    t.run_ticks(5)
end

local relief_in = t.pipe_pressure(1, 1)
local relief_out = t.pipe_pressure(5, 1)
assert(relief_in > 90.0, "the supply is charged: " .. relief_in)
assert(
    relief_out < relief_in - 20.0,
    "and the delivery main, diluted by the pipe just laid onto it, is"
        .. " well below it: " .. relief_out
)

t.click(v, 3, 1, t.target_at(3, 1, "pressure_valve"))
t.tick()
local relief_panel = t.ui(v)
assert(relief_panel.setpoints[1].label == "trip pressure", relief_panel.setpoints[1].label)
near(relief_panel.setpoints[1].max, 10132.5, 0.001, "tg's ONE_ATMOSPHERE * 100")

-- Arm it, trip pressure well above the supply. Nothing crosses, because
-- nothing upstream is over the line.
t.ui_act(v, "set", '{"field":"target","value":400}')
t.ui_act(v, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "armed", "the valve is armed")
t.run_seconds(30)
near(t.pipe_pressure(5, 1), relief_out, 0.5, "armed above its input, it passes nothing")
near(t.pipe_pressure(1, 1), relief_in, 0.5, "and holds the supply where it was")

-- Wind the trip pressure under the supply. Same valve, same position,
-- and now it relieves.
t.ui_act(v, "set", '{"field":"target","value":50}')
t.run_seconds(60)
assert(
    t.pipe_pressure(5, 1) > relief_out + 10.0,
    "under its input, the same valve opens: " .. t.pipe_pressure(5, 1)
)
assert(
    t.pipe_pressure(1, 1) < relief_in,
    "and the supply is what paid for it: " .. t.pipe_pressure(1, 1)
)
assert(
    t.ledger_has("MachineSetpoint", "target", "Player"),
    "re-dialling a relief valve is an attributed act"
)
