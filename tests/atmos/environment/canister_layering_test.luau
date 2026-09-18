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

-- The stack order, pair by pair: fixture < item < large_object.
-- Untargeted examine is the order oracle: it names the picture
-- under the tile centre, so it names whatever the stack puts on top.
local ORDER_MAP = [==[
(
    name: "canister layering order",
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
    items: [(2, 1, "floor_tile"), (3, 1, "floor_tile")],
    structures: [
        (2, 2, "player_spawn"),
        (1, 1, "vent"),
        (1, 1, "canister"),
        (2, 1, "utility_outlet_port"),
        (3, 1, "canister"),
        (1, 2, "utility_outlet_port"),
        (1, 2, "canister"),
        (3, 2, "canister"),
        (3, 2, "vent"),
    ],
)
]==]

t.world(ORDER_MAP, 7)
local q = t.join()
t.tick()

-- Every tile below holds a stack, so prove the stack before the order:
-- a placement that never landed must fail LOUD, never pass vacuous.
assert(
    t.target_at(q, 1, 1, "vent") ~= nil and t.target_at(q, 1, 1, "canister") ~= nil,
    "tile A holds the vent and the vessel"
)
assert(
    t.target_at(q, 2, 1, "utility_outlet_port") ~= nil and #t.items_at(2, 1) == 1,
    "tile B holds the outlet and the tiles"
)
assert(
    t.target_at(q, 3, 1, "canister") ~= nil and #t.items_at(3, 1) == 1,
    "tile C holds the vessel and the tiles"
)
assert(
    t.target_at(q, 1, 2, "utility_outlet_port") ~= nil and t.target_at(q, 1, 2, "canister") ~= nil,
    "tile D holds the outlet and the vessel"
)
assert(
    t.target_at(q, 3, 2, "canister") ~= nil and t.target_at(q, 3, 2, "vent") ~= nil,
    "tile E holds the vessel and the vent"
)

local function top(x: number, y: number): string
    local seen = t.examine(q, x, y)
    if seen == nil then
        return "nil"
    end
    return seen.title
end

-- The order, pair by pair: the vessel over the vent whichever of the two
-- the map lists first, the item over the anchored outlet, the vessel
-- over the item. A, B and D already hold -- the pick favours the later
-- map row of a same-rank pair, and the item rank already sits above the
-- fixture rank -- while C and E are the tripwires: today the item wins
-- C by rank and the later-listed vent wins E by row, and after the
-- large-object layer lands the vessel's rank wins both regardless.
assert(top(1, 1) == "canister", "A: the vessel over the first-listed vent: " .. top(1, 1))
assert(top(2, 1) == "floor tiles (30)", "B: the item over the outlet: " .. top(2, 1))
assert(top(3, 1) == "canister", "C: the vessel over the item: " .. top(3, 1))
assert(top(1, 2) == "canister", "D: the vessel over the outlet: " .. top(1, 2))
assert(top(3, 2) == "canister", "E: the vessel over the later-listed vent: " .. top(3, 2))
