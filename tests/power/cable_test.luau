local network_channels = require("@helpers/network_channels")

-- Wiring, on the line you chose.
--
-- tg has three power lines and they are the real thing: connection is
-- gated on the layer bitflag alone (cable.dm:121), so three cables can
-- share a tile and be three separate circuits. The colours -- red,
-- yellow, blue -- are the NAMES of those layers, not a second
-- mechanism; tg's own defines call them the "Red/Yellow/Blue Power
-- Line" (__DEFINES/power.dm:5,8,11).
--

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

-- A bare-plating bench, every tile of it within arm's reach of the
-- spawn: cable is subfloor work, so there is no finished floor here,
-- and an engineer standing still can wire the whole thing.
t.world(
    [==[(
    name: "wiring",
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
    structures: [(2, 2, "player_spawn")],
    items: [
        (1, 1, "cable_coil"),
        (3, 3, "cable_coil"),
        (1, 3, "wirecutters"),
    ],
    // One mapped stub in the corner, on the blue line and touching
    // nothing this spec lays: the length a fresh coil is asked to join.
    networks: [
        (x: 3, y: 3, network: "power", channel: "l3", kind: "cable", facing: 15),
    ],
)]==],
    7
)

local p = t.join()
t.tick()

-- ---------------------------------------------------------------
-- A fresh coil lays the line the station is already wired with.
-- tg's coil defaults to CABLE_LAYER_2 (cable.dm:513).
-- ---------------------------------------------------------------
t.click(p, 1, 1, t.target_at(p, 1, 1, "cable_coil")) -- pick the coil up
t.run_ticks(2)
for _, x in ipairs({ 1, 2, 3 }) do
    t.click(p, x, 1, nil, -14, 14)
    t.run_seconds(1.5)
end
assert(network_channels.at(1, 1, "power") == "l2", "a fresh coil lays the yellow line")
assert(network_channels.at(2, 1, "power") == "l2", "and keeps laying it")
assert(network_channels.at(3, 1, "power") == "l2")
assert(t.ledger_has("NetworkPlaced"), "every length is on the record")

-- ---------------------------------------------------------------
-- The dial. Using the coil in hand cycles the line it lays -- tg's
-- "Use it in hand to change the layer you are placing on"
-- (cable.dm:529). A radial menu there, a cycle here.
-- ---------------------------------------------------------------
local _ = t.messages(p)
t.use_self(p)
t.run_ticks(2)
assert(said(p, "You set the coil to the blue power line."), "yellow -> blue")
assert(t.ledger_has("ModeSet"), "which line you chose is on the record too")
t.use_self(p)
t.run_ticks(2)
assert(said(p, "You set the coil to the red power line."), "blue -> red")

-- The red line goes down THROUGH the yellow one. Both are on the
-- tile, and neither noticed the other.
t.click(p, 2, 1, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(2, 1, "power") == "l1,l2", "two lines share the tile: " .. network_channels.at(2, 1, "power"))
assert(network_channels.at(1, 1, "power") == "l2", "and the neighbours are untouched")

-- ---------------------------------------------------------------
-- Sharing a tile is not sharing a circuit. This is the whole point
-- of layers, and it is the same principle the plumbing keeps.
-- ---------------------------------------------------------------
t.click(p, 2, 2, nil, -14, 14)
t.run_seconds(1.5)
t.click(p, 2, 3, nil, -14, 14)
t.run_seconds(1.5)
local crossing_red = t.network_segment(2, 1, "power", "l1").segment
local crossing_yellow = t.network_segment(2, 1, "power", "l2").segment
assert(crossing_yellow ~= nil, "the yellow run reaches the crossing")
assert(crossing_red ~= nil, "so does the red one")
assert(crossing_yellow ~= crossing_red, "but they are two circuits, not one: " .. crossing_yellow)
assert(t.network_segment(2, 3, "power", "l1").segment == crossing_red, "the red run is continuous down the column")
assert(t.network_segment(2, 3, "power", "l2").segment == nil, "and the yellow line never went there")

-- ---------------------------------------------------------------
-- The dial is PER COIL. Park the red-set coil in the other hand and
-- pick up a fresh one: it arrives on yellow, knowing nothing about
-- what the first was set to.
-- ---------------------------------------------------------------
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 3, 3, t.target_at(p, 3, 3, "cable_coil")) -- the second coil
t.run_ticks(2)
t.click(p, 3, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(3, 2, "power") == "l2", "a second coil is a second dial")
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 1, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(1, 2, "power") == "l1", "and the first coil is still where it was left, ticks later")

-- ---------------------------------------------------------------
-- One snip, one cable. tg's wirecutters deconstruct the single cable
-- you clicked (cable.dm:210-221) and leave the rest of the tile
-- running. The alpha-tested sprite names the exact line; clearing a
-- shared tile costs one snip per line.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 3, t.target_at(p, 1, 3, "wirecutters")) -- the cutters
t.run_ticks(2)
t.click_network(p, 2, 1, assert(t.network_instance(2, 1, "power", "l2")))
t.run_seconds(1.5)
assert(
    network_channels.at(2, 1, "power") == "l1",
    "the yellow line parted and the red one under it did not: " .. network_channels.at(2, 1, "power")
)
assert(t.ledger_has("NetworkRemoved"), "sabotage is attributable")

-- Cutting the yellow line at the crossing really did sever that
-- circuit: the two halves are no longer one segment.
assert(t.network_segment(1, 1, "power", "l2").segment ~= t.network_segment(3, 1, "power", "l2").segment, "the yellow run is in two pieces now")

t.click_network(p, 2, 1, assert(t.network_instance(2, 1, "power", "l1")))
t.run_seconds(1.5)
assert(network_channels.at(2, 1, "power") == "", "a second snip takes the line beneath")
assert(t.network_instance(3, 3, "power", "l3") ~= nil, "the third line is mapped in the corner")
assert(network_channels.at(3, 3, "power") == "l2,l3" or network_channels.at(3, 3, "power") == "l3")
