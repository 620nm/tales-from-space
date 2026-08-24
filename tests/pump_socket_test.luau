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

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- ---------------------------------------------------------------
-- A PUMP FACING A BARE SOCKET MOVES GAS INTO IT.
--
-- One main of two lengths west of the pump, a socket east of it aimed
-- back at it, and no other plumbing on the map. Nothing else can decide
-- the pump's axis, and nothing else can be where the gas went.
-- ---------------------------------------------------------------
t.world([==[(
    name: "pump to socket",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#a....g#",
        "#......#",
        "########",
    ],
    spawns: [(3, 1)],
    // The whole of the plumbing: two lengths, and nothing anywhere near
    // the socket at (4, 2).
    pipes: [(1, 2, 4), (2, 2, 4)],
    structures: [
        (3, 2, "volume_pump"),
        (4, 2, "connector_port", { "dir": "west" }),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

local pump = t.structure_at(3, 2)
assert(pump ~= nil and pump.id == "volume_pump", "the map stood one there")
assert(pump.state == "off", "and tg's ships off")
assert(t.structure_at(4, 2).sprite == "connector_port_w", "the socket reaches the pump")
assert(t.pipe(4, 2) == 0, "with no length of pipe under it or beside it")

local charged = t.pipe_pressure(1, 2)
assert(charged > 90.0, "the mapped main opened the shift commissioned: " .. charged)

-- Nothing moves while it is off, which is what makes the next number
-- mean something.
t.run_seconds(5)
near(t.pipe_pressure(1, 2), charged, 0.001, "a pump that is off is a wall")

t.click(p, 3, 2, t.target_at(3, 2, "volume_pump"))
t.tick()
assert(t.ui(p), "the pump wears a panel")
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 2).state == "running", "it is on")

-- A volumetric pump has no notion of arriving (flow_devices_test.luau):
-- it keeps moving its input port's share and never asks whether the far
-- side has caught up, so a main whose only outlet is this machine ends
-- EMPTY. The socket's net -- the pump's own far mouth, plus a socket
-- that declares no volume of its own (portables_connector.dm) -- is the
-- only place on this map the gas can be, and the main can only have
-- paid it if the fit found a mouth where there was no length of pipe.
t.run_seconds(60)
local settled = t.pipe_pressure(1, 2)
assert(
    settled < charged * 0.05,
    "the main emptied itself through the pump into the socket: "
        .. charged .. " -> " .. settled
)

-- ---------------------------------------------------------------
-- A FACING SOMEBODY CHOSE IS NEVER OVERRULED.
--
-- The fit is a fallback and only a fallback. A fitting turned by hand
-- before the wrench keeps the axis it was turned to, even standing on
-- a tile whose only plumbing runs the other way -- which is the whole
-- complaint the fit exists to avoid making worse.
-- ---------------------------------------------------------------
t.world([==[(
    name: "chosen over fitted",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 3)],
    // East and west of (2, 2) and nothing north or south of it: the fit
    // has exactly one axis to offer, and it is not the one chosen.
    pipes: [(1, 2, 4), (3, 2, 4)],
    items: [(2, 3, "wrench"), (2, 2, "volume_pump_fitting")],
)]==], 7)

local q = t.join()
t.tick()
local fitting = t.target_at(2, 2, "volume_pump_fitting")
assert(fitting ~= nil, "the loose fitting is targetable")

-- South turns to west turns to north: two quarter-turns onto the axis
-- with no pipe on it at all.
t.rotate(q, 2, 2, fitting, true)
t.rotate(q, 2, 2, fitting, true)

t.click(q, 2, 3, t.target_at(2, 3, "wrench"))
t.run_ticks(2)
assert(t.hands(q).held == "wrench", "the wrench is in hand")
t.click(q, 2, 2, fitting)
t.run_seconds(2.5)

local raised = t.structure_at(2, 2)
assert(raised ~= nil and raised.id == "volume_pump", "the pump was fastened")
assert(
    raised.sprite == "volpump_off_ns",
    "the chosen north-south axis survived, with the run lying east-west: "
        .. tostring(raised.sprite)
)
