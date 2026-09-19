local network_channels = require("@helpers/network_channels")

-- A fitting's own emergency cell, from the mains going to the cell
-- going flat and back.
--
-- Every fitting carries tg's cell/emergency_light: 1.2 kJ, drained and
-- recharged at 2 W (content/structures/power/light.luau; cell.dm:237,
-- lights.dm:2). The engine decides where a fitting draws from -- the
-- grid, its own cell, or nothing -- and says so on the edge; what it
-- looks like on its cell is content/fixtures/light.luau: tg's vivid red
-- at a quarter of its reach and three quarters of its power
-- (light.dm:67-73, :536-538).
--
-- The room here is one its panel does NOT keep on reserve: the panel
-- flags L1 and the room hangs off L3, so when the mains go the room's
-- socket goes with them and the fitting is on nothing but its cell.

local function near(got: number, want: number, tol: number, why: string)
    assert(math.abs(got - want) <= tol, why .. ": " .. got .. " vs " .. want)
end

-- The electrical pass runs on every multiple of this many ticks (0.5 Hz,
-- the engine's docs/power/pass.md); `pass()` runs through the next one
-- and one tick past it.
local POWER_EVERY = 40
local TICK_HZ = 20
local function pass()
    t.run_ticks(POWER_EVERY - t.now() % POWER_EVERY + 1)
end

local EMERGENCY_RED = "#FF3232"
-- A lit tube bills range x power x the rate (tg light.dm:307): 120 W at
-- 6 and 1.0 (tests/power/power_ports_test.luau), and its cell's 2 W
-- recharge rides the same socket.
local TUBE_W = 120.0
local CELL_W = 2.0
local CELL_J = 1200.0

-- A generator on the backbone (L2) into a panel flagged for L1; the room
-- circuit is L3, east to a socket with a fitting in cord reach.
t.world(
    [==[(
    name: "emergency cell",
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

-- ---------------------------------------------------------------
-- 1. ON THE GRID. The tube burns what its prototype says, off the
--    socket, with a full cell nobody is paying to top up.
-- ---------------------------------------------------------------
local lamp = assert(t.light_at(5, 2))
assert(lamp.lit and lamp.emits, "the fitting is burning")
local TUBE = lamp.color
assert(TUBE ~= EMERGENCY_RED, "in its own tube's colour: " .. TUBE)
near(lamp.range, 6.0, 1e-6, "at its full reach")
near(lamp.power, 1.0, 1e-6, "and its full power")
local cell = assert(t.store_at(5, 2))
assert(cell.source == "grid", "it draws off the grid: " .. tostring(cell.source))
near(cell.charge_j, CELL_J, 1e-6, "its cell is full")
near(assert(assert(t.ports_at(4, 1, "power")).channels["l3"]).out_w, TUBE_W, 1e-3, "a full cell bills nothing")

-- ---------------------------------------------------------------
-- 2. THE MAINS GO. Part the backbone: the panel is on its cell, which it
--    keeps for L1 alone, so the room's socket is dead and the fitting
--    is on its own.
-- ---------------------------------------------------------------
t.click(p, 3, 2, t.target_at(p, 3, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
t.click_network(p, 3, 1, assert(t.network_instance(3, 1, "power", "l2")))
t.run_seconds(1.5)
assert(network_channels.at(3, 1, "power") == "", "the backbone is parted")
pass()
local switched = t.now() - 1

assert(assert(t.store_at(4, 1)).on_reserve, "the panel is on its cell")
assert(not assert(t.outlet_at(7, 1)).powered, "and keeps nothing on the room circuit")
cell = assert(t.store_at(5, 2))
assert(cell.source == "store", "the fitting is on its own cell: " .. tostring(cell.source))
lamp = assert(t.light_at(5, 2))
assert(lamp.lit and lamp.emits, "and still burning")
assert(lamp.color == EMERGENCY_RED, "in tg's emergency red: " .. lamp.color)
near(lamp.range, 1.5, 1e-6, "at a quarter of its reach")
near(lamp.power, 0.75, 0.01, "and three quarters of its power")

-- It drains at 2 W: four joules a pass, and `switched` was its first.
local PASS_J = POWER_EVERY / TICK_HZ * CELL_W
local c0 = cell.charge_j
near(c0, CELL_J - PASS_J, 1e-6, "one pass on the cell so far")
for _ = 1, 50 do
    pass()
end
near(assert(t.store_at(5, 2)).charge_j, c0 - 50 * PASS_J, 1e-6, "the cell drains at 2 W")

-- 1.2 kJ at 2 W is ten minutes of light, and not a pass more.
t.run_ticks(switched + 600 * TICK_HZ - POWER_EVERY + 1 - t.now())
lamp = assert(t.light_at(5, 2))
assert(lamp.lit and lamp.color == EMERGENCY_RED, "the last pass of the cell still burns red")
t.run_ticks(POWER_EVERY)
lamp = assert(t.light_at(5, 2))
assert(not lamp.lit and not lamp.emits, "ten minutes on, the cell is flat and the fitting dark")
cell = assert(t.store_at(5, 2))
assert(cell.source == "none", "on nothing at all: " .. tostring(cell.source))
near(cell.charge_j, 0.0, 1e-6, "with nothing left in it")

-- ---------------------------------------------------------------
-- 3. THE MAINS COME BACK. Lay the parted length again: the fitting is
--    on the grid in its own tube, and its cell charges at 2 W billed to
--    the socket it burns from.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 2, t.target_at(p, 3, 2, "cable_coil"))
t.run_ticks(2)
t.click(p, 3, 1)
t.run_seconds(1.5)
assert(network_channels.at(3, 1, "power") == "l2", "the backbone is whole again")
pass()
pass()

lamp = assert(t.light_at(5, 2))
assert(lamp.lit and lamp.emits, "the fitting is burning again")
assert(lamp.color == TUBE, "in its own tube: " .. lamp.color)
near(lamp.range, 6.0, 1e-6, "at its full reach")
near(lamp.power, 1.0, 1e-6, "and its full power")
cell = assert(t.store_at(5, 2))
assert(cell.source == "grid", "off the grid: " .. tostring(cell.source))
assert(cell.charging == "charging", "and topping its cell up: " .. cell.charging)
near(
    assert(assert(t.ports_at(4, 1, "power")).channels["l3"]).out_w,
    TUBE_W + CELL_W,
    1e-3,
    "the tube and its 2 W recharge on the room circuit's books"
)
local c1 = cell.charge_j
for _ = 1, 10 do
    pass()
end
near(assert(t.store_at(5, 2)).charge_j, c1 + 10 * PASS_J, 1e-6, "the cell fills at 2 W")
