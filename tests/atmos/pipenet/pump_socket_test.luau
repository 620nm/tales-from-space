local network_matter = require("@helpers/network_matter")
local network_channels = require("@helpers/network_channels")

-- A pump standing beside a bare socket, and the fit that used to look
-- straight past it.
--
-- Which way a machine nobody aimed points is the engine's own answer:
-- the facing whose every mouth has something to reach. It used to probe
-- RAW PIPE and nothing else, while the join rule it stands in for
-- treats an adjacent component mouth as a reciprocal endpoint exactly
-- as it treats a length of pipe (docs/ATMOS.md §4). So a volumetric
-- pump set beside a socket, with the supply main on its other side,
-- fell through to the fallback -- the first cardinal with a LENGTH to
-- reach, which is the main -- and came up with its output mouth
-- pointed at the main it was supposed to draw from and its input
-- pointed at nothing. It ran. It moved not one mole. It wore exactly
-- the picture a working one wears.
--
-- connector_test.luau owns what an unplumbed socket does; this is the
-- other half, a socket somebody plumbed with a MACHINE instead of a
-- length. The second half of the file is the other side of the same
-- rule: a facing somebody chose is never a facing the fit may
-- overrule.

local ui_controls = require("@helpers/ui_controls")

local function near(a: number, b: number, slack: number, what: string)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- ---------------------------------------------------------------
-- A PUMP FACING A BARE SOCKET MOVES GAS INTO IT.
--
-- One main of two lengths west of the pump, a socket east of it aimed
-- back at it, and no other plumbing on the map. Nothing else can decide
-- the pump's axis, and nothing else can be where the gas went.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "pump to socket",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'a': (composition: (components: [(component: "station_base")])),
        'g': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#a....g#",
        "#......#",
        "########",
    ],
    // The whole of the plumbing: two lengths, and nothing anywhere near
    // the socket at (4, 2).
    networks: [
        (x: 1, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
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
    ],
    structures: [
        (3, 1, "player_spawn"),
        (3, 2, "volume_pump"),
        (4, 2, "connector_port", { "pipe": "west" }),
        (1, 1, "apc"),
    ],

)]==],
    7
)

local p = t.join()
t.tick()

local pump = t.structure_at(3, 2)
assert(pump ~= nil and pump.id == "volume_pump", "the map stood one there")
assert(pump.state == "off", "and tg's ships off")
assert(assert(t.structure_at(4, 2)).sprite == "connector_port_w", "the socket reaches the pump")
assert(network_channels.at(4, 2, "pipe") == "", "with no length of pipe under it or beside it")

local charged = assert(network_matter.pressure(1, 2))
assert(charged > 90.0, "the mapped main opened the shift commissioned: " .. charged)

-- Nothing moves while it is off, which is what makes the next number
-- mean something.
t.run_seconds(5)
near(assert(network_matter.pressure(1, 2)), charged, 0.001, "a pump that is off is a wall")

t.click(p, 3, 2, t.target_at(p, 3, 2, "volume_pump"))
t.tick()
assert(t.ui(p), "the pump wears a panel")
ui_controls.toggle(p, "power")
t.run_ticks(2)
assert(assert(t.structure_at(3, 2)).state == "running", "it is on")

-- A volumetric pump has no notion of arriving (flow_devices_test.luau):
-- it keeps moving its input port's share and never asks whether the far
-- side has caught up, so a main whose only outlet is this machine ends
-- EMPTY. The socket's net -- the pump's own far mouth, plus a socket
-- that declares no volume of its own (portables_connector.dm) -- is the
-- only place on this map the gas can be, and the main can only have
-- paid it if the fit found a mouth where there was no length of pipe.
t.run_seconds(60)
local settled = assert(network_matter.pressure(1, 2))
assert(
    settled < charged * 0.05,
    "the main emptied itself through the pump into the socket: " .. charged .. " -> " .. settled
)

-- ---------------------------------------------------------------
-- A FACING SOMEBODY CHOSE IS NEVER OVERRULED.
--
-- The fit is a fallback and only a fallback. A fitting turned by hand
-- before the wrench keeps the axis it was turned to, even standing on
-- a tile whose only plumbing runs the other way -- which is the whole
-- complaint the fit exists to avoid making worse.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "chosen over fitted",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    structures: [(2, 3, "player_spawn")],
    // East and west of (2, 2) and nothing north or south of it: the fit
    // has exactly one axis to offer, and it is not the one chosen.
    networks: [
        (x: 1, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 3, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
    items: [(2, 3, "wrench"), (2, 2, "volume_pump_fitting")],
)]==],
    7
)

local q = t.join()
t.tick()
local fitting = t.target_at(q, 2, 2, "volume_pump_fitting")
assert(fitting ~= nil, "the loose fitting is targetable")

-- South turns to west turns to north: two quarter-turns onto the axis
-- with no pipe on it at all.
t.rotate(q, 2, 2, fitting, true)
t.rotate(q, 2, 2, fitting, true)

t.click(q, 2, 3, t.target_at(q, 2, 3, "wrench"))
t.run_ticks(2)
assert(t.hands(q).held == "wrench", "the wrench is in hand")
t.click(q, 2, 2, fitting)
t.run_seconds(2.5)

local raised = t.structure_at(2, 2)
assert(raised ~= nil and raised.id == "volume_pump", "the pump was fastened")
assert(
    raised.sprite == "volpump_off_n",
    "the chosen facing survived, with the run lying east-west: " .. tostring(raised.sprite)
)
