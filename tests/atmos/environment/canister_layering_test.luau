local network_matter = require("@helpers/network_matter")
local network_channels = require("@helpers/network_channels")

local composition = require("@helpers/composition")

-- A portable vessel does not make its whole tile an opaque click target.
-- A click on its pixels opens the vessel; a click on transparent ground
-- reaches the deck between the vessel and its underfloor socket.

local MAP = [==[
(
    name: "canister layering",
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    items: [(2, 2, "floor_tile")],
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
    structures: [
        (2, 2, "player_spawn"),
        (3, 1, "connector_port"),
        (3, 1, "canister"),
    ],
)
]==]

t.world(MAP, 7)
local p = t.join()
t.tick()

local canister = t.target_at(p, 3, 1, "canister")
local tiles = t.target_at(p, 2, 2, "floor_tile")
assert(canister ~= nil and tiles ~= nil, "the map placed both click targets")
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, tiles)))
t.tick()
assert(t.hands(p).held == "floor_tile", "the player picked up the tiles")

-- The exact entity claim is the vessel, not the deck or socket below it.
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, canister)))
t.run_seconds(1)
assert(composition.matches(3, 1, { "station_base" }), "clicking the vessel did not tile the deck")
t.ui_close(p)

-- A pixel where only turf is visible spends the tile on the plating.
composition.click_deck(p, 3, 1)
t.run_seconds(1)
assert(composition.matches(3, 1, { "station_base", "floor_tiles" }), "the transparent click reached the deck")
local standing = t.structure_at(3, 1)
assert(
    standing and standing.id == "canister" and standing.state == "anchored",
    "the vessel remains fastened above the new floor"
)
assert(network_channels.at(3, 1, "pipe") == "", "tiling invented no raw pipe under the socket")
assert(network_matter.pressure(2, 1) ~= nil, "the neighbouring run remains connected")
