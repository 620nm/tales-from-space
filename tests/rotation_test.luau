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
