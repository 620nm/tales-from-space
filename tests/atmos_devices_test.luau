-- The machines that stand IN a pipe run: the manual valve and the gas
-- pump.
--
-- Everything before this hung off a pipenet — a vent, a canister on a
-- port. These are boundaries BETWEEN two of them, which is what almost
-- the whole tg atmospherics kit is, and the difference shows up as
-- topology: a shut valve is a wall two runs cannot see past, an open
-- one is not a machine at all but a single body of gas, and a pump is
-- the only thing on the station that can move air the wrong way up a
-- pressure gradient.
--
-- Layer masks are tg's five piping layers; 4 is layer 3, the
-- distribution run.
local DISTRO = 4

-- The two volumes the whole substrate is priced in. A length of pipe is
-- tg's `UNARY_PIPE_VOLUME * 2` = 70 L; every device port is its 200 L
-- component mixture (components_base.dm:39). A net holds its lengths
-- plus the ports of the machines that open into it, which is exactly
-- what these specs check the arithmetic against.
local PIPE_M3 = 0.070
local PORT_M3 = 0.200

local function net_m3(lengths, ports)
    return lengths * PIPE_M3 + ports * PORT_M3
end

-- The ideal gas law at room temperature, so a spec can audit the books
-- rather than trust a direction.
local function moles(kpa, m3)
    return kpa * 1000.0 * m3 / (8.314 * 293.15)
end

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- ---------------------------------------------------------------
-- A SHUT VALVE IS A WALL.
--
-- One distribution main, six lengths, with a valve standing on the
-- middle of it. The run does NOT pass through the machine: the length
-- under it belongs to no net, and the two sides are two networks that
-- happen to be in a straight line.
--
-- The proof is gas, not topology. A passive vent over the west half
-- opens it to the room; tear the hull and the west main empties into
-- space, while the east main — three tiles away, on the same layer,
-- on what a mapper drew as one line — never loses a mole.
-- ---------------------------------------------------------------
t.world([==[(
    name: "shut valve",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'p': (turf: Plating, fixture: Some(PassiveVent)),
    },
    rows: [
        "########",
        "#......#",
        "#p.....#",
        "#......#",
        "########",
    ],
    spawns: [(4, 3)],
    pipes: [(1, 2, 4), (2, 2, 4), (3, 2, 4), (4, 2, 4), (5, 2, 4), (6, 2, 4)],
    structures: [(3, 2, "manual_valve")],
)]==], 7)

local p = t.join()
t.tick()

assert(t.structure_at(3, 2).id == "manual_valve", "the map stood a valve on the main")
assert(t.structure_at(3, 2).state == "shut", "and it opens the shift shut")

-- The map laid pipe under the machine, and the machine took the tile.
assert(t.pipe(3, 2) == DISTRO, "there is pipe under the valve")
assert(
    t.pipe_pressure(3, 2) == nil,
    "but no net claims it: a run does not pass through a machine"
)

-- Each side is a net of its own, and each is 200 L bigger than its
-- lengths because the port in the valve's mouth belongs to it.
assert(t.pipe_pressure(2, 2) > 90.0, "the west main is handed over charged")
assert(t.pipe_pressure(5, 2) > 90.0, "and so is the east one")

local west_m3 = net_m3(2, 1) -- (1,2) (2,2) plus the valve's back port
local east_m3 = net_m3(3, 1) -- (4,2) (5,2) (6,2) plus its front port
local held = moles(t.pipe_pressure(2, 2), west_m3) + moles(t.pipe_pressure(5, 2), east_m3)

-- Open the hull. Whatever is on the west main goes out with the room.
t.fault(1, 1, t.now() + 4)
t.run_seconds(40)
assert(t.is_breached(1, 1), "the fault opened the room")

local drained = t.pipe_pressure(2, 2)
local sealed = t.pipe_pressure(5, 2)
assert(drained < 25.0, "the vented main emptied: " .. drained)
assert(
    sealed > 90.0,
    "and the main on the far side of a shut valve never lost a mole: " .. sealed
)
assert(held > 0.0, "the books were readable to begin with")

-- ---------------------------------------------------------------
-- AN OPEN VALVE IS NOT A MACHINE, IT IS ONE NET.
--
-- tg's open valve does not pump. It fuses its two pipelines and lets
-- them reconcile as one (`custom_reconcilation`, valve.dm:56-61), so
-- the pressures equalise by VOLUME and there is no per-tick machine
-- anywhere. Shutting it divides the gas back the same way — the very
-- arithmetic a wrench through a charged line already used.
--
-- The east main is mapped, so it is commissioned; the west main is
-- laid by hand during the shift, so it is empty. A valve between them
-- is the only thing keeping those two facts apart.
-- ---------------------------------------------------------------
t.world([==[(
    name: "open valve",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "pipe")],
    pipes: [(4, 1, 4), (5, 1, 4), (6, 1, 4)],
    structures: [(3, 1, "manual_valve")],
)]==], 7)

local q = t.join()
t.tick()

-- Run the west half by hand. Two lengths, and the valve's back port
-- has something to open into.
t.click(q, 1, 2, t.target_at(1, 2, "pipe"))
t.run_ticks(2)
for _, x in ipairs({ 1, 2 }) do
    t.click(q, x, 1)
    t.run_seconds(1.5)
end
assert(t.pipe(2, 1) == DISTRO, "the west main went down")

local WEST_M3 = net_m3(2, 1)
local EAST_M3 = net_m3(3, 1)
assert(t.pipe_pressure(2, 1) < 1.0, "a run you built yourself starts empty")
assert(t.pipe_pressure(5, 1) > 90.0, "the mapped run beside it did not")
local before = moles(t.pipe_pressure(2, 1), WEST_M3) + moles(t.pipe_pressure(5, 1), EAST_M3)

-- Walk over to it, empty-handed. A wheel is a thing you put a HAND on:
-- with a coil of pipe in it you are laying pipe, exactly as tg's
-- `interact` is the empty-hand path and an item in hand is not.
t.drop(q)
t.run_ticks(2)
for _ = 1, 2 do
    t.move(q, "east")
    t.run_ticks(5)
end

-- Turn it. tg gives the wheel a second and will not be hurried: a
-- tick in, nothing has happened yet.
local _ = t.messages(q)
t.click(q, 3, 1, t.target_at(3, 1, "manual_valve"))
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "shut", "a second is a second")
assert(t.pipe_pressure(2, 1) < 1.0, "and nothing has crossed yet")

-- And it will not be double-clicked out of that second: tg refuses
-- every interaction while `switching` is set (valve.dm:63-69), so a
-- second click is not a cancel, not a queue, and not a second turn.
t.click(q, 3, 1, t.target_at(3, 1, "manual_valve"))
t.run_seconds(1.5)
assert(t.structure_at(3, 1).state == "open", "and then the wheel is over")
assert(said(q, "The manual valve is open."), "which it says so")
assert(
    t.ledger_has("AtmosDeviceSet", "manual_valve"),
    "turning an atmospherics valve is on the record"
)

-- One body of gas: the same pressure at both ends, and that pressure
-- is what the east main's air comes to when it is given the whole
-- volume to spread through.
t.run_seconds(1)
local fused = t.pipe_pressure(2, 1)
near(fused, t.pipe_pressure(5, 1), 0.5, "both ends of one net read alike")
near(
    fused,
    101.325 * EAST_M3 / (WEST_M3 + EAST_M3),
    2.0,
    "and they read what the volume says they should"
)

-- Shut it again. Two nets, and every mole still accounted for.
t.click(q, 3, 1, t.target_at(3, 1, "manual_valve"))
t.run_seconds(2)
assert(t.structure_at(3, 1).state == "shut", "shut again")
t.run_seconds(1)
local after = moles(t.pipe_pressure(2, 1), WEST_M3) + moles(t.pipe_pressure(5, 1), EAST_M3)
assert(
    math.abs(after - before) < before * 0.02,
    "opening and shutting a valve makes and loses nothing: "
        .. before .. " mol -> " .. after .. " mol"
)
assert(
    t.pipe_pressure(2, 1) > 40.0,
    "and the west main, which nobody ever filled, is charged: "
        .. t.pipe_pressure(2, 1)
)

-- ---------------------------------------------------------------
-- A PUMP MOVES AIR UPHILL.
--
-- Everything else in the engine settles a difference: a vent, a
-- passive vent, an open valve all move gas from more to less until
-- there is no more difference to move. A pump is the machine that
-- makes one, and this is the proof — it takes a main at one
-- atmosphere and a main below it and ends with the LOW one higher
-- than the high one, then stops dead at its setpoint.
--
-- The output main is mapped one length long, so it opens the shift
-- commissioned; laying two more lengths onto it spreads that same air
-- through a bigger volume and drops it below an atmosphere. That is
-- the difference the pump then works against.
-- ---------------------------------------------------------------
t.world([==[(
    name: "gas pump",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "############",
        "#..........#",
        "#..........#",
        "############",
    ],
    spawns: [(6, 2)],
    items: [(6, 2, "pipe")],
    pipes: [(1, 1, 4), (2, 1, 4), (3, 1, 4), (4, 1, 4), (6, 1, 4)],
    structures: [(5, 1, "gas_pump")],
)]==], 7)

local r = t.join()
t.tick()
assert(t.structure_at(5, 1).id == "gas_pump", "the pump is where the map put it")
assert(t.structure_at(5, 1).state == "off", "and tg's pump ships off")

-- Lengthen the output main: the same air, more room to be in, and so
-- less pressure. Four lengths east of the one the map drew.
t.click(r, 6, 2, t.target_at(6, 2, "pipe"))
t.run_ticks(2)
for x = 7, 10 do
    t.click(r, x, 1)
    t.run_seconds(1.5)
    if x < 10 then
        t.move(r, "east")
        t.run_ticks(5)
    end
end
assert(t.pipe(10, 1) == DISTRO, "the output main is five lengths now")

local IN_M3 = net_m3(4, 1) -- (1,1)..(4,1) plus the pump's back port
local OUT_M3 = net_m3(5, 1) -- (6,1)..(10,1) plus its front port
local supply = t.pipe_pressure(2, 1)
local delivery = t.pipe_pressure(7, 1)
assert(supply > 90.0, "the supply main is charged: " .. supply)
assert(delivery < 80.0, "and the delivery main is not: " .. delivery)
local books = moles(supply, IN_M3) + moles(delivery, OUT_M3)

-- An idle pump is a length of pipe. Give it every chance.
t.run_seconds(20)
near(t.pipe_pressure(7, 1), delivery, 0.5, "an off pump moves nothing")
near(t.pipe_pressure(2, 1), supply, 0.5, "from either end")

-- Switch it on, hands empty. A pump has no wheel: tg flips it on the
-- click.
t.drop(r)
t.run_ticks(2)
for _ = 1, 3 do
    t.move(r, "west")
    t.run_ticks(5)
end
local _ = t.messages(r)
t.click(r, 5, 1, t.target_at(5, 1, "gas_pump"))
t.run_ticks(2)
assert(t.structure_at(5, 1).state == "running", "a switch is not a wheel")
assert(said(r, "The gas pump is running."), "and it says which way it went")
assert(t.ledger_has("AtmosDeviceSet", "gas_pump"), "switching it is on the record")

-- One atmos pass moves what is standing in the 200 L input port and no
-- more (tg drains `airs[1]` and stops). So it starts, and it is
-- nowhere near finished.
t.run_ticks(11)
local first = t.pipe_pressure(7, 1)
assert(first > delivery + 1.0, "the first pass moved something: " .. first)
assert(
    first < 101.0,
    "and nothing like all of it -- a pump is throttled by its own port: " .. first
)

-- Let it run. It arrives at the setpoint and stops there.
t.run_seconds(60)
local out = t.pipe_pressure(7, 1)
local back = t.pipe_pressure(2, 1)
near(out, 101.325, 1.5, "the delivery main came up to one atmosphere")
assert(out < 101.5, "and not one kPa past it: " .. out)
assert(
    back < out,
    "which it pushed UPHILL: supply " .. back .. " kPa, delivery " .. out .. " kPa"
)
assert(
    math.abs(moles(back, IN_M3) + moles(out, OUT_M3) - books) < books * 0.02,
    "and every mole came out of the supply, not out of nowhere"
)

-- ---------------------------------------------------------------
-- A PUMP ONLY PUMPS ONE WAY.
--
-- tg's binary devices are node1-in, node2-out: the port BEHIND the
-- facing is the input and the port it FACES is the output
-- (`get_node_connects`, binary_devices.dm:19-20). Stand one with its
-- face to the charged main and its back to a slack one, switch it on,
-- and nothing crosses — where anything that merely EQUALISED would
-- have emptied one into the other.
-- ---------------------------------------------------------------
t.world([==[(
    name: "backwards pump",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "pipe")],
    pipes: [(2, 1, 4), (4, 1, 4), (5, 1, 4), (6, 1, 4)],
    structures: [(3, 1, "gas_pump")],
)]==], 7)

local s = t.join()
t.tick()

-- Lengthen the BACK main, so the pump's input is the slack one.
t.click(s, 1, 2, t.target_at(1, 2, "pipe"))
t.run_ticks(2)
t.click(s, 1, 1)
t.run_seconds(1.5)

local slack = t.pipe_pressure(2, 1)
local charged = t.pipe_pressure(5, 1)
assert(slack < charged - 10.0, "the input main is the slack one: " .. slack)

t.drop(s)
t.run_ticks(2)
for _ = 1, 2 do
    t.move(s, "east")
    t.run_ticks(5)
end
t.click(s, 3, 1, t.target_at(3, 1, "gas_pump"))
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "running", "switched on")
t.run_seconds(60)

near(t.pipe_pressure(2, 1), slack, 0.5, "a pump does not pull its output back")
near(t.pipe_pressure(5, 1), charged, 0.5, "nor let its output down the pipe")

-- ---------------------------------------------------------------
-- A MACHINE BINDS TO ITS OWN LAYER AND NOTHING ELSE.
--
-- Two pipes on different layers do not connect (tg's
-- atmosmachinery.dm:350), and that has to hold for a machine standing
-- on one of them too. A valve on the distribution layer laid over a
-- layer-1 line takes nothing: the length under it is still part of
-- that run, and turning the wheel does not move a mole.
-- ---------------------------------------------------------------
t.world([==[(
    name: "wrong layer",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(3, 2)],
    pipes: [(2, 1, 1), (3, 1, 1), (4, 1, 1), (5, 1, 1)],
    structures: [(3, 1, "manual_valve")],
)]==], 7)

local u = t.join()
t.tick()
assert(t.structure_at(3, 1).id == "manual_valve", "the valve is on the line")
assert(t.pipe(3, 1) == 1, "which is a LAYER 1 line")
assert(
    t.pipe_pressure(3, 1, 4) == nil,
    "there is no distribution run here at all"
)
assert(
    t.pipe_pressure(3, 1, 1) > 90.0,
    "and the length under the valve is still part of the layer-1 run"
)
local layer1 = t.pipe_pressure(5, 1, 1)

t.click(u, 3, 1, t.target_at(3, 1, "manual_valve"))
t.run_seconds(2)
assert(t.structure_at(3, 1).state == "open", "the wheel still turns")
t.run_seconds(2)
near(t.pipe_pressure(5, 1, 1), layer1, 0.5, "and the line it is not on never noticed")
assert(
    t.pipe_pressure(3, 1, 1) ~= nil,
    "the length under it still belongs to that run"
)
