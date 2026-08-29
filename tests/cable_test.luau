-- Wiring, piece by piece, on the colour you chose.
--
-- Cable is not a flag on a tile: it is a set of PIECES, each one
-- `(colour, d1, d2)` in BYOND's direction alphabet, and the picture on
-- the floor is the shape the sim floods (docs/POWER.md). A knot is
-- `d1 == 0` -- centre out to one edge -- and everything else runs edge
-- to edge without stopping in the middle. Only a knot offers power to
-- what stands on it, which is what lets a run cross a tile and feed it
-- nothing, and lets two colours each terminate on one tile.
--
-- The gesture is tg's `place_turf` and `cable_join`
-- (pipecleaners.dm:311-440, the maintained copy of old cable.dm:593-700)
-- and its one rule is that A PIECE POINTS AT ITS ELECTRICIAN.
--
-- The colours: 1 = red, 2 = yellow, 4 = blue -- tg's own
-- "Red/Yellow/Blue Power Line" (__DEFINES/power.dm:5,8,11).
local RED, YELLOW, BLUE = 1, 2, 4
-- The direction bits every piece is spelled in.
local NORTH, SOUTH, EAST = 1, 2, 4
local SE, NW = 6, 9

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

local function has_piece(x, y, colour, d1, d2)
    for _, piece in ipairs(t.cable_segments(x, y)) do
        if piece.colour == colour and piece.d1 == d1 and piece.d2 == d2 then
            return true
        end
    end
    return false
end

local function only_piece(x, y, colour, d1, d2)
    return #t.cable_segments(x, y) == 1 and has_piece(x, y, colour, d1, d2)
end

-- A bare-plating bench: cable is subfloor work, so there is no finished
-- floor here and an engineer can wire the whole room on foot.
t.world([==[(
    name: "wiring",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "#....#",
        "#....#",
        "######",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 1, "cable_coil"),
        (4, 3, "cable_coil"),
        (1, 2, "wirecutters"),
    ],
    // One mapped piece on the blue line, in the corner and touching
    // nothing this spec lays: a map spells pieces the same way a coil
    // lays them.
    cables: [(4, 1, 4, 0, 1)],
)]==], 7)

local p = t.join()
t.tick()

t.click(p, 1, 1, t.target_at(1, 1, "cable_coil"))
t.run_ticks(2)
assert(t.hands(p).held == "cable_coil", "coil in hand")

-- ---------------------------------------------------------------
-- A CLICK LAYS A KNOT POINTING BACK AT YOU. tg's `place_turf` takes
-- `get_dir(tile, user)` and ties the wire down facing you, so walking a
-- corridor and clicking ahead draws the run out behind you. A fresh
-- coil is on the yellow line -- tg's coil defaults to CABLE_LAYER_2
-- (cable.dm:513), the backbone the shipped station runs.
-- ---------------------------------------------------------------
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(only_piece(2, 1, YELLOW, 0, SOUTH), "one knot, reaching south at the man who laid it")
assert(t.cable_at(2, 1) == YELLOW, "and the tile carries the yellow line")
assert(t.segment_at(2, 1).l2 ~= nil, "a knot is a node: something here could clip on")
assert(t.ledger_has("CableLaid"), "every piece is on the record")
assert(
    #t.ledger_rows("ItemConsumed") == 1,
    "and one length off the reel paid for it, tg's `use(1)`"
)

-- The same click twice is one piece, not two. tg refuses a knot that
-- already reaches that way, and says so (pipecleaners.dm:337-340).
local _ = t.messages(p)
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(said(p, "There's already a cable at that position."), "the second click is refused out loud")
assert(#t.cable_segments(2, 1) == 1, "and nothing was laid twice")

-- ---------------------------------------------------------------
-- A PIECE POINTING AT YOU GETS A MATCHING KNOT UNDER YOUR FEET. Click
-- the piece rather than the deck and tg walks the run one tile closer:
-- a knot on your own tile facing back at it (pipecleaners.dm:383-405).
-- The two knots meet through the edge they share and are one circuit.
-- ---------------------------------------------------------------
t.click_subfloor(p, 2, 1, "cable", YELLOW, 0, SOUTH)
t.run_seconds(1.5)
assert(only_piece(2, 2, YELLOW, 0, NORTH), "a knot under the electrician, reaching back north")
assert(
    t.segment_at(2, 2).l2 == t.segment_at(2, 1).l2,
    "two tiles, two knots, one circuit"
)

-- ---------------------------------------------------------------
-- A KNOT GROWS INTO A LENGTH -- and a length is not a node. Click the
-- knot from a tile it does NOT point at and its edge plus your bearing
-- become the two ends (pipecleaners.dm:408-437). What was a stub is now
-- a wire crossing the tile, and a wire crossing a tile offers its middle
-- to nobody: a socket standing there gets nothing until somebody ties a
-- knot down beside it (docs/POWER.md).
-- ---------------------------------------------------------------
t.move(p, "east")
t.run_seconds(0.5)
local coils = t.count_items("cable_coil")
t.click_subfloor(p, 2, 2, "cable", YELLOW, 0, NORTH)
t.run_seconds(1.5)
assert(only_piece(2, 2, YELLOW, NORTH, EAST), "the stub is a north-east length now")
assert(t.cable_at(2, 2) == YELLOW, "the line still runs under the tile")
assert(t.segment_at(2, 2).l2 == nil, "but a run that merely crosses is no node")
assert(t.segment_at(2, 1).l2 ~= nil, "while the knot next door still is one")
assert(
    t.count_items("cable_coil") == coils + 1,
    "the knot came up as a length while the longer piece went down"
)

-- ---------------------------------------------------------------
-- The dial. Using the coil in hand cycles the colour it lays -- tg's
-- "Use it in hand to change the layer you are placing on"
-- (cable.dm:529). A radial menu there, a cycle here.
-- ---------------------------------------------------------------
_ = t.messages(p)
t.use_self(p)
t.run_ticks(2)
assert(said(p, "You set the coil to the blue power line."), "yellow -> blue")
assert(t.ledger_has("ModeSet"), "which line you chose is on the record too")
t.use_self(p)
t.run_ticks(2)
assert(said(p, "You set the coil to the red power line."), "blue -> red")

-- ---------------------------------------------------------------
-- TWO COLOURS MAY EACH TERMINATE ON ONE TILE. A knot belongs to its own
-- colour and the centre of a tile is not shared, so the red knot goes
-- down through the yellow one and neither notices the other.
-- ---------------------------------------------------------------
t.move(p, "west")
t.run_seconds(0.5)
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(t.cable_at(2, 1) == RED + YELLOW, "both colours end here: " .. t.cable_at(2, 1))
assert(has_piece(2, 1, RED, 0, SOUTH) and has_piece(2, 1, YELLOW, 0, SOUTH), "one knot each")
local crossing = t.segment_at(2, 1)
assert(crossing.l1 ~= nil and crossing.l2 ~= nil, "and both offer power here")
assert(crossing.l1 ~= crossing.l2, "but they are two circuits, not one: " .. crossing.l2)

-- ---------------------------------------------------------------
-- A DIAGONAL IS AN ORDINARY PIECE. The alphabet has eight letters, so a
-- click from a corner lays NW/SE the way a click from beside lays N/S,
-- and the two meet through the corner all four tiles share (tg's
-- `mergeDiagonalsNetworks`, cable.dm:257-279).
-- ---------------------------------------------------------------
t.move(p, "south")
t.run_seconds(0.5)
t.move(p, "east")
t.run_seconds(0.5)
t.click(p, 4, 4)
t.run_seconds(1.5)
assert(only_piece(4, 4, RED, 0, NW), "a knot reaching north-west, out of the corner")
t.click_subfloor(p, 4, 4, "cable", RED, 0, NW)
t.run_seconds(1.5)
assert(only_piece(3, 3, RED, 0, SE), "and its answer reaching south-east")
assert(t.segment_at(3, 3).l1 ~= nil, "the corner is wired")
assert(t.segment_at(3, 3).l1 == t.segment_at(4, 4).l1, "and the diagonal joined the two")

-- ---------------------------------------------------------------
-- THE DIAL IS PER COIL. Park the red-set coil in the idle hand and pick
-- up a fresh one: it arrives on yellow, knowing nothing about what the
-- first was set to, and the first is still red when you take it back.
-- ---------------------------------------------------------------
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 4, 3, t.target_at(4, 3, "cable_coil"))
t.run_ticks(2)
assert(t.hands(p).held == "cable_coil", "the second coil is in hand")
t.click(p, 3, 4)
t.run_seconds(1.5)
assert(t.cable_at(3, 4) == YELLOW, "a second coil is a second dial")
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 2, 3)
t.run_seconds(1.5)
assert(t.cable_at(2, 3) == RED, "and the first coil is still where it was left, ticks later")

-- ---------------------------------------------------------------
-- ONE SNIP, ONE PIECE. tg's wirecutters deconstruct the single cable
-- you clicked (cable.dm:210-221) and leave the rest of the tile
-- running. The alpha-tested sprite names the exact piece, and what it
-- was made of comes back as one length of coil.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.move(p, "west")
t.run_seconds(0.5)
t.move(p, "north")
t.run_seconds(0.5)
t.click(p, 1, 2, t.target_at(1, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
coils = t.count_items("cable_coil")
t.click_subfloor(p, 2, 1, "cable", RED, 0, SOUTH)
t.run_seconds(1.5)
assert(only_piece(2, 1, YELLOW, 0, SOUTH), "the red knot parted and the yellow one did not")
assert(t.cable_at(2, 1) == YELLOW, "so the tile is down to one colour: " .. t.cable_at(2, 1))
assert(t.count_items("cable_coil") == coils + 1, "and the piece came back as one length")
assert(t.ledger_has("CableCut"), "sabotage is attributable")

-- ---------------------------------------------------------------
-- A KNOT BESIDE A LENGTH IS HOW A CROSSED TILE IS GIVEN POWER. tg
-- refuses only a knot already reaching that way, so the length running
-- under your feet does not stop you tying one down -- and on your own
-- tile the piece runs the way you are FACING (`place_turf`; the last
-- move was north).
-- ---------------------------------------------------------------
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 2, 2)
t.run_seconds(1.5)
assert(has_piece(2, 2, YELLOW, NORTH, EAST), "the length that crossed the tile is still there")
assert(has_piece(2, 2, YELLOW, 0, NORTH), "with a knot tied down beside it, facing the way you stand")
assert(#t.cable_segments(2, 2) == 2, "two pieces, one tile")
assert(t.segment_at(2, 2).l2 ~= nil, "the crossed tile offers power now")
assert(
    t.segment_at(2, 2).l2 == t.segment_at(2, 1).l2,
    "and it is the same circuit the run next door is on"
)

-- The third colour is a real one, mapped in the corner and untouched by
-- any of this.
assert(only_piece(4, 1, BLUE, 0, NORTH), "the mapped blue piece is exactly what the map said")
assert(t.cable_at(4, 1) == BLUE, "and nothing this spec laid went near it")
