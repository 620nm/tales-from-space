-- Wiring, on the line you chose.
--
-- tg has three power lines and they are the real thing: connection is
-- gated on the layer bitflag alone (cable.dm:121), so three cables can
-- share a tile and be three separate circuits. The colours -- red,
-- yellow, blue -- are the NAMES of those layers, not a second
-- mechanism; tg's own defines call them the "Red/Yellow/Blue Power
-- Line" (__DEFINES/power.dm:5,8,11).
--
-- The masks: 1 = red, 2 = yellow, 4 = blue.
local RED, YELLOW, BLUE = 1, 2, 4

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
t.world([==[(
    name: "wiring",
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
    spawns: [(2, 2)],
    items: [
        (1, 1, "cable_coil"),
        (3, 3, "cable_coil"),
        (1, 3, "wirecutters"),
    ],
    // One mapped stub in the corner, on the blue line and touching
    // nothing this spec lays. A map with no cable at all boots the grid
    // in abstract mode (everything powered, no segments flooded), so
    // this is what makes the wiring a real graph to ask questions of.
    cables: [(3, 3, 4)],
)]==], 7)

local p = t.join()
t.tick()

-- ---------------------------------------------------------------
-- A fresh coil lays the line the station is already wired with.
-- tg's coil defaults to CABLE_LAYER_2 (cable.dm:513).
-- ---------------------------------------------------------------
t.click(p, 1, 1, t.target_at(1, 1, "cable_coil")) -- pick the coil up
t.run_ticks(2)
for _, x in ipairs({ 1, 2, 3 }) do
    t.click(p, x, 1)
    t.run_seconds(1.5)
end
assert(t.cable_at(1, 1) == YELLOW, "a fresh coil lays the yellow line")
assert(t.cable_at(2, 1) == YELLOW, "and keeps laying it")
assert(t.cable_at(3, 1) == YELLOW)
assert(t.ledger_has("CableLaid"), "every length is on the record")

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
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(
    t.cable_at(2, 1) == YELLOW + RED,
    "two lines share the tile: " .. t.cable_at(2, 1)
)
assert(t.cable_at(1, 1) == YELLOW, "and the neighbours are untouched")

-- ---------------------------------------------------------------
-- Sharing a tile is not sharing a circuit. This is the whole point
-- of layers, and it is the same principle the plumbing keeps.
-- ---------------------------------------------------------------
t.click(p, 2, 2)
t.run_seconds(1.5)
t.click(p, 2, 3)
t.run_seconds(1.5)
local crossing = t.segment_at(2, 1)
assert(crossing.branch ~= nil, "the yellow run reaches the crossing")
assert(crossing.feeder ~= nil, "so does the red one")
assert(
    crossing.branch ~= crossing.feeder,
    "but they are two circuits, not one: " .. crossing.branch
)
assert(
    t.segment_at(2, 3).feeder == crossing.feeder,
    "the red run is continuous down the column"
)
assert(t.segment_at(2, 3).branch == nil, "and the yellow line never went there")

-- ---------------------------------------------------------------
-- The dial is PER COIL. Park the red-set coil in the other hand and
-- pick up a fresh one: it arrives on yellow, knowing nothing about
-- what the first was set to.
-- ---------------------------------------------------------------
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 3, 3, t.target_at(3, 3, "cable_coil")) -- the second coil
t.run_ticks(2)
t.click(p, 3, 2)
t.run_seconds(1.5)
assert(t.cable_at(3, 2) == YELLOW, "a second coil is a second dial")
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 1, 2)
t.run_seconds(1.5)
assert(
    t.cable_at(1, 2) == RED,
    "and the first coil is still where it was left, ticks later"
)

-- ---------------------------------------------------------------
-- One snip, one cable. tg's wirecutters deconstruct the single cable
-- you clicked (cable.dm:210-221) and leave the rest of the tile
-- running; with no cursor to aim under the deck, a snip takes the
-- topmost line. Clearing a shared tile costs one snip per line.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 3, t.target_at(1, 3, "wirecutters")) -- the cutters
t.run_ticks(2)
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(
    t.cable_at(2, 1) == RED,
    "the yellow line parted and the red one under it did not: " .. t.cable_at(2, 1)
)
assert(t.ledger_has("CableCut"), "sabotage is attributable")

-- Cutting the yellow line at the crossing really did sever that
-- circuit: the two halves are no longer one segment.
assert(
    t.segment_at(1, 1).branch ~= t.segment_at(3, 1).branch,
    "the yellow run is in two pieces now"
)

t.click(p, 2, 1)
t.run_seconds(1.5)
assert(t.cable_at(2, 1) == 0, "a second snip takes the line beneath")
assert(BLUE == 4, "the third line is a real layer, mapped in the corner")
assert(t.cable_at(3, 3) == BLUE + YELLOW or t.cable_at(3, 3) == BLUE)
