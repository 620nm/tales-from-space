-- Loose atmos fittings rotate in place: Alt+left is clockwise and
-- Alt+right is counter-clockwise in the browser; this spec enters the
-- same server commands directly and proves the direction survives the
-- fitting-to-machine construction round trip.
t.world([==[(
    name: "rotation",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 2)],
    items: [
        (1, 2, "wrench"),
        (2, 2, "connector_port_fitting"),
    ],
    // North is the engine's old automatic choice. West is also valid,
    // so a player-selected west can be distinguished from that fallback.
    pipes: [(2, 1, 4), (1, 2, 4)],
)]==], 7)

local p = t.join()
t.tick()
local fitting = t.target_at(2, 2, "connector_port_fitting")
assert(fitting ~= nil, "the streamed loose fitting is targetable")

-- South -> east counter-clockwise, east -> south clockwise, then
-- south -> west clockwise. Both browser bindings share this command.
t.rotate(p, 2, 2, fitting, false)
t.rotate(p, 2, 2, fitting, true)
t.rotate(p, 2, 2, fitting, true)
assert(#t.ledger_rows("Rotated") == 3, "every accepted quarter-turn is recorded")

t.click(p, 1, 2, t.target_at(1, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "the wrench is in hand")
t.click(p, 2, 2, fitting)
t.run_seconds(2.5)

local port = t.structure_at(2, 2)
assert(port ~= nil and port.id == "connector_port", "the fitting became a port")
assert(port.sprite == "connector_port_w", "the chosen west facing survived anchoring")
assert(t.target_at(2, 2, "connector_port_fitting") == nil, "the loose fitting was consumed")

-- Taking it back up returns the component item rather than deleting it,
-- and that item remembers the direction when it is fastened again.
t.click(p, 2, 2, t.target_at(2, 2, "connector_port"))
t.run_seconds(2.5)
local returned = t.target_at(2, 2, "connector_port_fitting")
assert(returned ~= nil, "unwrenching returned the fitting item")
t.click(p, 2, 2, returned)
t.run_seconds(2.5)
port = t.structure_at(2, 2)
assert(port ~= nil and port.sprite == "connector_port_w", "the returned fitting kept west")

-- Anchoring is the boundary: the same explicit claim cannot turn live
-- network topology behind the server's back.
local anchored = t.target_at(2, 2, "connector_port")
t.rotate(p, 2, 2, anchored, true)
t.tick()
port = t.structure_at(2, 2)
assert(port.sprite == "connector_port_w", "an anchored fixture refuses rotation")
assert(#t.ledger_rows("Rotated") == 3, "a refused turn creates no ledger row")

-- A connector carries a Stub, but ordinary binary and trinary devices
-- do not. Their loose fitting's Facing must survive the same boundary:
-- it decides both the anchored sprite and which mouths join the grid.
t.world([==[(
    name: "rotated device topology",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#######",
        "#.....#",
        "#.....#",
        "#.....#",
        "#######",
    ],
    spawns: [(4, 3)],
    items: [(4, 3, "wrench"), (3, 2, "manual_valve_fitting")],
    // Both axes are completely plumbed. Automatic alignment therefore
    // chooses north first; an explicit east is the only reason this
    // valve may join the west/east pair instead.
    pipes: [(3, 1, 4), (2, 2, 4), (4, 2, 4), (3, 3, 4)],
    structures: [(1, 2, "passive_vent")],
)]==], 7)

local q = t.join()
t.tick()
local valve_fitting = t.target_at(3, 2, "manual_valve_fitting")
assert(valve_fitting ~= nil, "the valve fitting is targetable")
t.rotate(q, 3, 2, valve_fitting, false) -- south -> east

t.click(q, 4, 3, t.target_at(4, 3, "wrench"))
t.run_ticks(2)
t.click(q, 3, 2, valve_fitting)
t.run_seconds(2.5)

local valve = t.structure_at(3, 2)
assert(valve ~= nil and valve.id == "manual_valve", "the rotated valve was fastened")
assert(valve.sprite == "valve_shut_ew", "a non-stub device keeps the fitting's facing")
assert(t.pipe(3, 2) == 0, "the valve replaces its centre length")

-- Open it, then vent the room. The passive vent is attached to the
-- west run. East drains only if the valve's actual topology is EW;
-- north remains charged only if it did not silently fall back to NS.
t.drop(q)
t.run_ticks(2)
t.click(q, 3, 2, t.target_at(3, 2, "manual_valve"))
t.run_seconds(2)
assert(t.structure_at(3, 2).state == "open", "the valve opened")
t.fault(5, 1, t.now() + 4)
t.run_seconds(80)
assert(t.is_breached(5, 1), "the room opened to space")
assert(
    t.pipe_pressure(4, 2) < 25.0,
    "the selected east mouth joined the vented west run: " .. t.pipe_pressure(4, 2)
)
assert(
    t.pipe_pressure(3, 1) > 90.0,
    "the unselected north run stayed sealed: " .. t.pipe_pressure(3, 1)
)
