local network_channels = require("@helpers/network_channels")
local ui_controls = require("@helpers/ui_controls")

-- What a fitting on its own cell burns, and what it keeps burning while
-- the world goes on talking to it.
--
-- On its cell a fitting wears tg's low-power look -- vivid red, a
-- quarter of its reach, three quarters of the cell's level never under
-- half (light.dm:67-73, :536-538) -- set once, at the switch
-- (content/fixtures/light.luau, docs/POWER.md). It keeps its hardwired
-- edge to the panel while it is off the grid, so a flag can still
-- arrive, and a flag arriving must not knock it back onto the stack:
-- tg's low-power branch supersedes every area effect (light.dm:282-289).
--
-- The room hangs off L3, which the panel does not keep on reserve; the
-- panel keeps L1 alone. Turning L3 off at the panel puts the fitting on
-- its cell with the mains still up, so the panel's own `low_power` flag
-- arrives only later, when the backbone is parted.

local function near(got: number, want: number, tol: number, why: string)
    assert(math.abs(got - want) <= tol, why .. ": " .. got .. " vs " .. want)
end

-- The electrical pass runs on every multiple of this many ticks (0.5 Hz,
-- the engine's docs/power/pass.md); `pass()` runs through the next one
-- and one tick past it.
local POWER_EVERY = 40
local function pass()
    t.run_ticks(POWER_EVERY - t.now() % POWER_EVERY + 1)
end

local EMERGENCY_RED = "#FF3232"
local LIGHT_FLAGS = "lunatic/tfs:light_flags"

t.world(
    [==[(
    name: "emergency look",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
        'l': (composition: (components: [(component: "station_base")]), fixture: Some(Light)),
    },
    rows: [
        "#########",
        "#G.....o#",
        "#....l..#",
        "#########",
    ],
    structures: [
        (3, 2, "player_spawn"),
        (4, 1, "apc", { "l1_reserve": true }),
    ],
    items: [(3, 2, "wirecutters"), (3, 2, "cable_coil")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
    ],
    labels: [(4, 1, "Engineering")],
)]==],
    0
)

local p = t.join()
t.tick()
pass()
pass()

-- The panel's own window, opened with an empty hand, and its L3 port
-- turned to `mode`.
local function room_circuit(mode: string)
    assert(t.hands(p).held == nil, "an empty hand at the panel")
    t.click(p, 4, 1, t.target_at(p, 4, 1))
    t.tick()
    ui_controls.toggle(p, "ports.mode", "l3:" .. mode)
    t.tick()
    local port = assert(assert(t.ports_at(4, 1, "power")).channels["l3"])
    assert(port.mode == mode, "the room circuit's port is " .. port.mode)
end

-- How many times the one fitting here has written its flag stack. The
-- record keeps a digest of each value, not the value, so a spec counts.
local function flag_writes(): number
    local wrote = 0
    for _, row in ipairs(t.ledger_rows("VarSet")) do
        if row.key == LIGHT_FLAGS then
            wrote += 1
        end
    end
    return wrote
end

-- ---------------------------------------------------------------
-- 1. ON THE GRID, in its own tube at its own reach.
-- ---------------------------------------------------------------
local lamp = assert(t.light_at(5, 2))
local TUBE = lamp.color
assert(lamp.lit and TUBE ~= EMERGENCY_RED, "the fitting burns its own tube: " .. TUBE)
near(lamp.range, 6.0, 1e-6, "at its full reach")
near(lamp.power, 1.0, 1e-6, "and its full power")

-- ---------------------------------------------------------------
-- 2. ITS ROOM CIRCUIT OFF, ITS CELL PART-SPENT. The pass after the port
--    turns is the switch, and the power it burns is three quarters of
--    the level the cell had then: between the floor and a full cell's.
-- ---------------------------------------------------------------
t.set_store_charge(5, 2, 0.9)
room_circuit("ignore")
pass()

local cell = assert(t.store_at(5, 2))
assert(cell.source == "store", "the fitting is on its own cell: " .. tostring(cell.source))
local panel = assert(t.store_at(4, 1))
assert(panel.fed and not panel.on_reserve, "with the panel still on the mains")
local on_cell = math.max(0.5, 0.75 * cell.level)
assert(on_cell > 0.6 and on_cell < 0.7, "a cell at nine tenths burns between the floor and full: " .. on_cell)
lamp = assert(t.light_at(5, 2))
assert(lamp.lit and lamp.color == EMERGENCY_RED, "in tg's emergency red: " .. lamp.color)
near(lamp.range, 1.5, 1e-6, "at a quarter of its reach")
near(lamp.power, on_cell, 1e-6, "at three quarters of its cell's level")
local writes = flag_writes()

-- ---------------------------------------------------------------
-- 3. A FLAG ARRIVES. Part the backbone: the panel goes onto its cell
--    and puts `low_power` on its network, which the fitting hears over
--    the edge it kept. It files the flag and burns red all the same.
-- ---------------------------------------------------------------
t.click(p, 3, 2, t.target_at(p, 3, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
t.click_network(p, 3, 1, assert(t.network_instance(3, 1, "power", "l2")))
t.run_seconds(1.5)
assert(network_channels.at(3, 1, "power") == "", "the backbone is parted")
pass()
t.run_ticks(2)

assert(assert(t.store_at(4, 1)).on_reserve, "the panel is on its cell")
-- Its source never moved, so the only word that relit it is the flag.
assert(assert(t.store_at(5, 2)).source == "store", "the fitting is still on its cell")
assert(flag_writes() > writes, "and it heard its panel's flag")
lamp = assert(t.light_at(5, 2))
assert(lamp.lit and lamp.color == EMERGENCY_RED, "the cell's red outranks the flag: " .. lamp.color)
near(lamp.range, 1.5, 1e-6, "at the cell's reach, not the tube's")
near(lamp.power, on_cell, 1e-6, "at the power it switched at")

-- ---------------------------------------------------------------
-- 4. THE MAINS BACK, THE ROOM CIRCUIT STILL OFF. The panel comes off its
--    cell and clears the flag; the fitting is on its own cell still.
-- ---------------------------------------------------------------
writes = flag_writes()
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 2, t.target_at(p, 3, 2, "cable_coil"))
t.run_ticks(2)
t.click(p, 3, 1)
t.run_seconds(1.5)
assert(network_channels.at(3, 1, "power") == "l2", "the backbone is whole again")
pass()
t.run_ticks(2)

assert(not assert(t.store_at(4, 1)).on_reserve, "the panel is off its cell")
assert(assert(t.store_at(5, 2)).source == "store", "the fitting is still on its cell")
assert(flag_writes() > writes, "and it heard the clear")
lamp = assert(t.light_at(5, 2))
assert(lamp.color == EMERGENCY_RED, "and still red: " .. lamp.color)
near(lamp.range, 1.5, 1e-6, "at the cell's reach")

-- ---------------------------------------------------------------
-- 5. THE ROOM CIRCUIT BACK. The fitting is on the grid, in its tube, at
--    the tube's reach and power.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
pass()
room_circuit("output")
pass()

assert(assert(t.store_at(5, 2)).source == "grid", "the fitting is back on the grid")
lamp = assert(t.light_at(5, 2))
assert(lamp.lit and lamp.color == TUBE, "in its own tube: " .. lamp.color)
near(lamp.range, 6.0, 1e-6, "at its full reach")
near(lamp.power, 1.0, 1e-6, "and its full power")

-- ---------------------------------------------------------------
-- 6. UNDER THE FLOOR. A cell under two thirds would burn under half at
--    three quarters of its level; the fitting burns half instead.
-- ---------------------------------------------------------------
t.set_store_charge(5, 2, 0.5)
room_circuit("ignore")
pass()

cell = assert(t.store_at(5, 2))
assert(cell.source == "store", "the fitting is on its cell again: " .. tostring(cell.source))
assert(0.75 * cell.level < 0.5, "a cell this low is under the floor: " .. cell.level)
lamp = assert(t.light_at(5, 2))
assert(lamp.lit and lamp.color == EMERGENCY_RED, "in red: " .. lamp.color)
near(lamp.range, 1.5, 1e-6, "at a quarter of its reach")
near(lamp.power, 0.5, 1e-6, "and never under half its power")

local raised = {}
for _, row in ipairs(t.ledger_rows("script_error")) do
    raised[#raised + 1] = tostring(row.file) .. ": " .. tostring(row.why)
end
assert(#raised == 0, "no handler raised: " .. table.concat(raised, " | "))
