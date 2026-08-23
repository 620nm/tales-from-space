-- A portable vessel does not make its whole tile an opaque click target.
-- A click on its pixels opens the vessel; a click on transparent ground
-- reaches the deck between the vessel and its underfloor socket.

local MAP = [==[
(
    name: "canister layering",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "floor_tile")],
    pipes: [(1, 1, 4), (2, 1, 4)],
    structures: [
        (3, 1, "connector_port"),
        (3, 1, "canister"),
    ],
)
]==]

t.world(MAP, 7)
local p = t.join()
t.tick()

local canister = t.target_at(3, 1, "canister")
local tiles = t.target_at(2, 2, "floor_tile")
assert(canister ~= nil and tiles ~= nil, "the map placed both click targets")
t.click(p, 2, 2, tiles)
t.tick()
assert(t.hands(p).held == "floor_tile", "the player picked up the tiles")

-- The exact entity claim is the vessel, not the deck or socket below it.
t.click(p, 3, 1, canister)
t.run_seconds(1)
assert(t.turf(3, 1) == "plating", "clicking the vessel did not tile the deck")
t.ui_close(p)

-- Omitting the target is the browser saying its hit-test landed on a
-- transparent pixel. That ground click spends the tile on the plating.
t.click(p, 3, 1)
t.run_seconds(1)
assert(t.turf(3, 1) == "floor", "the transparent click reached the deck")
local standing = t.structure_at(3, 1)
assert(standing and standing.id == "canister" and standing.state == "anchored",
    "the vessel remains fastened above the new floor")
assert(t.pipe(3, 1) == 0, "tiling invented no raw pipe under the socket")
assert(t.pipe_pressure(2, 1) ~= nil, "the neighbouring run remains connected")
