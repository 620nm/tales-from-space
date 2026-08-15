-- The three things you DO to an in-line machine that are not gas:
-- open its panel, put a wrench to it, and cut its power.
--
-- flow_devices_test.luau proves what each machine does with the air.
-- This is about the surfaces -- which of them answers a hand and which
-- answers a window, what a wrench is told when the machine is running,
-- and what a pump does on a branch nothing is feeding.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

local function lying_at(x, y, id)
    for _, item in ipairs(t.items_at(x, y)) do
        if item == id then
            return true
        end
    end
    return false
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function moles(kpa, m3)
    return kpa * 1000.0 * m3 / (8.314 * 293.15)
end

local PIPE_M3 = 0.070
local PORT_M3 = 0.200

-- ---------------------------------------------------------------
-- ONE GESTURE, TWO MEANINGS.
--
-- tg's manual valve and its digital twin are the same subtype doing
-- the same thing to gas, and differ in one line: the digital one turns
-- on the `ALLOW_SILICON` flag the manual one carries a comment about
-- deliberately withholding ("Intentionally no allow_silicon flag",
-- valve.dm:13 vs 86). That is a design statement -- the manual valve is
-- the atmospherics component nobody can operate from a chair -- and
-- keeping it means keeping the asymmetry at the click.
--
-- So an empty hand means two different things, exactly as it does in
-- tg: `interact()` on a valve starts the wheel turning (valve.dm:63),
-- `interact()` on a machine with an interface opens it (pump.dm:68).
-- ---------------------------------------------------------------
t.world([==[(
    name: "two valves",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#############",
        "#...........#",
        "#...........#",
        "#############",
    ],
    spawns: [(3, 2)],
    items: [(6, 1, "pipe")],
    // Two mains that never touch: the manual valve's on row 1, the
    // digital one's on row 2, x ranges disjoint so no length of either
    // is ever adjacent to a length of the other.
    pipes: [
        (1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4),
        (7, 2, 4), (8, 2, 4), (10, 2, 4), (11, 2, 4),
    ],
    structures: [(3, 1, "manual_valve"), (9, 2, "digital_valve")],
)]==], 7)

local p = t.join()
t.tick()
assert(t.structure_at(9, 2).id == "digital_valve", "the map stood one there")
assert(t.structure_at(9, 2).state == "shut", "shut, like its twin")

-- The manual valve: no window at all, and a wheel that takes tg's
-- second.
t.click(p, 3, 1, t.target_at(3, 1, "manual_valve"))
t.tick()
assert(t.ui(p) == nil, "a manual valve has no panel to open")
assert(t.structure_at(3, 1).state == "shut", "and a second is a second")
t.run_seconds(1.5)
assert(t.structure_at(3, 1).state == "open", "then the wheel is over")
assert(said(p, "The manual valve is open."), "and it says where it landed")

-- Lengthen the digital valve's west main by one length, so the two
-- sides of it hold different pressures and fusing them is visible.
walk(p, "east")
walk(p, "east")
walk(p, "east")
t.click(p, 6, 1, t.target_at(6, 1, "pipe"))
t.run_ticks(2)
t.click(p, 6, 2)
t.run_seconds(1.5)
assert(t.pipe(6, 2) == 4, "the west main is three lengths now")
t.drop(p)
t.run_ticks(2)

local WEST_M3 = 3 * PIPE_M3 + PORT_M3
local EAST_M3 = 2 * PIPE_M3 + PORT_M3
local west = t.pipe_pressure(7, 2)
local east = t.pipe_pressure(11, 2)
assert(east > west + 10.0, "the two sides differ: " .. west .. " / " .. east)
local level = (moles(west, WEST_M3) + moles(east, EAST_M3))
    / (WEST_M3 + EAST_M3)
    * (8.314 * 293.15)
    / 1000.0

-- The digital valve: a panel, and no wheel. Same machine, same words
-- for its two positions -- they come out of its own content file --
-- and it throws on the command rather than a second later.
walk(p, "east")
walk(p, "east")
walk(p, "east")
t.click(p, 9, 2, t.target_at(9, 2, "digital_valve"))
t.tick()
local panel = t.ui(p)
assert(panel, "a digital valve answers an empty hand with a panel")
assert(panel.kind == "flow", "the panel the whole roster shares")
assert(panel.toggles[1].on_text == "open", panel.toggles[1].on_text)
assert(panel.toggles[1].off_text == "shut")
assert(panel.toggles[1].label == "valve", "and it is a valve, not a pump")

t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(9, 2).state == "open", "no wheel: it throws on the command")
assert(
    t.ledger_has("AtmosDeviceSet", "digital_valve", "Player"),
    "and opening a main from a panel is on the record, against the player"
)

-- It is still a VALVE: open, it does not pump, it fuses. The two mains
-- become one body of gas and settle where their volumes say.
t.run_seconds(2)
near(t.pipe_pressure(7, 2), t.pipe_pressure(11, 2), 0.5, "both ends of one net read alike")
near(t.pipe_pressure(7, 2), level, 2.0, "and read what the volumes say they should")

-- ---------------------------------------------------------------
-- A PUMP ON A DEAD BRANCH.
--
-- tg's binary base draws idle power (binary_devices.dm:5-6) and every
-- powered device in the family opens `process_atmos` with `if(!on ||
-- !is_operational) return`. This station has a scrap of cable in one
-- corner and nothing else -- no APC, no feeder -- so the branch under
-- the pump is dead, and the pump is a length of pipe with a switch on
-- it.
--
-- (The other half of this, an APC shedding its equipment channel
-- mid-job and the pump picking the line back up when the power returns,
-- is sim/tests/flow.rs -- it needs a wired grid to shed.)
-- ---------------------------------------------------------------
t.world([==[(
    name: "dead branch",
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
    spawns: [(4, 2)],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4)],
    structures: [(3, 1, "gas_pump")],
    // One stub in the corner, touching nothing. A map with no cable at
    // all boots the grid in abstract mode (everything powered), so this
    // is what makes the station's wiring a real graph to be absent from.
    cables: [(6, 2, 4)],
)]==], 7)

local d = t.join()
t.tick()
t.run_seconds(3)

t.click(d, 3, 1, t.target_at(3, 1, "gas_pump"))
t.tick()
local supply = nil
for _, r in ipairs(t.ui(d).readouts) do
    if r.label == "supply" then
        supply = r.value
    end
end
assert(supply == "dead", "the panel says the mains are not behind it: " .. tostring(supply))

-- Wind the setpoint up so a working pump would have plenty to do, and
-- throw the switch.
t.ui_act(d, "set", '{"field":"target","value":300}')
t.ui_act(d, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.ui(d).toggles[1].on == true, "the switch is on")
assert(
    t.structure_at(3, 1).state == "off",
    "and the machine is still drawn dead, which is tg's `on &&"
        .. " is_operational` picking the picture"
)

local dead_in = t.pipe_pressure(1, 1)
local dead_out = t.pipe_pressure(5, 1)
t.run_seconds(60)
near(t.pipe_pressure(5, 1), dead_out, 0.5, "an unpowered pump moves nothing")
near(t.pipe_pressure(1, 1), dead_in, 0.5, "out of either end")

-- ---------------------------------------------------------------
-- YOU DO NOT UNBOLT A RUNNING PUMP.
--
-- tg's `can_unwrench` refuses while the machine is on and says why:
-- "You cannot unwrench [src], turn it off first!" (pump.dm:103-107).
-- Here that is the machine's two POSITIONS being two assembly states
-- and the wrench row naming one of them, so the refusal is the one the
-- construction interpreter already writes for a tool used in the wrong
-- state. No new rule, and the same sentence.
--
-- Then the round trip the whole atmospherics kit now has: the machine
-- comes up as a fitting, the run it was interrupting becomes whole
-- again, and bolting the fitting back down parts the run once more.
-- ---------------------------------------------------------------
t.world([==[(
    name: "unbolting",
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
    spawns: [(4, 2)],
    items: [(4, 2, "wrench")],
    // Pipe under the machine as well, so "the run is whole again" is a
    // thing this spec can actually see.
    pipes: [(1, 1, 4), (2, 1, 4), (3, 1, 4), (4, 1, 4), (5, 1, 4)],
    structures: [(3, 1, "gas_pump")],
)]==], 7)

local w = t.join()
t.tick()
assert(t.pipe_pressure(3, 1) == nil, "no net claims the tile the machine is on")

-- Switch it on through its panel, then pick the wrench up.
t.click(w, 3, 1, t.target_at(3, 1, "gas_pump"))
t.tick()
t.ui_act(w, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "running", "the pump is running")

t.click(w, 4, 2, t.target_at(4, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(w).held == "wrench", "wrench in hand")

local _ = t.messages(w)
t.click(w, 3, 1, t.target_at(3, 1, "gas_pump"))
t.run_seconds(2.5)
assert(
    said(w, "The gas pump must be off first."),
    "the refusal names the state the job wants"
)
assert(t.structure_at(3, 1).id == "gas_pump", "and the pump is still bolted down")

-- The panel is still open and still in reach, so the switch is right
-- there -- which is the whole point of it being a windowed machine.
t.ui_act(w, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "off", "switched off")

t.click(w, 3, 1, t.target_at(3, 1, "gas_pump"))
t.run_ticks(1)
assert(t.structure_at(3, 1) ~= nil, "one tick in, it is still bolted down")
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "and two seconds in, it is up")
assert(
    t.pipe_pressure(3, 1) ~= nil,
    "and the run the machine was interrupting is whole again"
)
near(
    t.pipe_pressure(1, 1),
    t.pipe_pressure(5, 1),
    0.5,
    "which is one main from end to end now"
)

-- What came up is a FITTING -- and not necessarily lying where the
-- machine stood. Taking a machine out of a charged line hands its tile
-- back to the run, and the gas that rushes in shoves loose things
-- downwind (sim/wind.rs). So look for it AROUND the tile, which is
-- also what the engineer who just did it has to do.
local fx, fy = nil, nil
for dx = -1, 1 do
    for dy = -1, 1 do
        if lying_at(3 + dx, 1 + dy, "gas_pump_fitting") then
            fx, fy = 3 + dx, 1 + dy
        end
    end
end
assert(fx, "the machine came up as a fitting")

-- Put it back. Pick it up in the free hand, carry it onto the tile,
-- and step off before wrenching: a machine needs the deck clear, where
-- a fitting hides under it.
t.swap_hands(w)
t.click(w, fx, fy, t.target_at(fx, fy, "gas_pump_fitting"))
t.run_ticks(2)
assert(t.hands(w).held == "gas_pump_fitting", "the fitting is in hand")
walk(w, "north")
walk(w, "west")
t.drop(w)
t.run_ticks(2)
assert(lying_at(3, 1, "gas_pump_fitting"), "dropped back over the run")
walk(w, "south")

t.swap_hands(w)
t.click(w, 3, 1, t.target_at(3, 1, "gas_pump_fitting"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) ~= nil, "the machine is standing again")
assert(t.structure_at(3, 1).id == "gas_pump", "and it is the same machine")
assert(t.structure_at(3, 1).state == "off", "a machine you just bolted down is off")
t.run_seconds(1)
assert(
    t.pipe_pressure(3, 1) == nil,
    "and the run is parted again: the tile belongs to the machine"
)
