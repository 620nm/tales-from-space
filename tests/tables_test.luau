-- Tables: a row of them reads as one surface, and a shift can raise and
-- take apart every one of them.
--
-- Two claims, and neither is about arithmetic. The engine's own tests
-- own the junction rule (`crates/lunatic-server/src/structures/
-- smoothing.rs` and sim/tests/smoothing.rs); what this file asserts is
-- what THIS PACK declared with it -- that steel and reinforced tables
-- agree they are one surface and wooden ones do not, which is three
-- words in three content files (tg's `smoothing_groups`,
-- tables_racks.dm:29-31, 628-629, 744-755), and that the ladder from
-- two rods to a table and back to two rods is walkable by a player
-- holding ordinary tools.
--
-- Seed 7, as every construction spec here uses: nothing below draws
-- from the shift RNG, and pinning it keeps that true if something ever
-- starts.

-- ---- one surface, and where it stops --------------------------------
-- Five tables in a row, mapped, so the junctions are the ones a station
-- comes up wearing. Left to right: two steel, one reinforced, two
-- wooden.
t.world([==[(
    name: "furniture showroom",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(6, 2)],
    structures: [
        (1, 1, "table"), (2, 1, "table"), (3, 1, "reinforced_table"),
        (4, 1, "wood_table"), (5, 1, "wood_table"),
    ],
)]==], 7)

t.join()
t.tick()

-- The picture is the whole assertion: a table wears the frame its
-- neighbours chose, and the numbers are tg's own bits -- east is 4,
-- west is 8 (`icon_smoothing.dm`'s NORTH/SOUTH/EAST/WEST junctions).
-- No corners appear anywhere below because a corner bit is only set
-- where both cardinals beside it already were, and a single row has no
-- vertical neighbours at all.
local west_end = t.structure_at(1, 1)
assert(west_end.id == "table", "a steel table stands at the west end")
assert(west_end.sprite == "table-4",
    "with one neighbour, to its east: " .. tostring(west_end.sprite))

-- The middle steel table has a table on either side -- and one of them
-- is reinforced. It counts, because both files said "tables".
local middle = t.structure_at(2, 1)
assert(middle.sprite == "table-12",
    "joined both ways, steel to reinforced: " .. tostring(middle.sprite))

-- The reinforced table joins back, and its OTHER neighbour is wood,
-- which it does not see at all.
local reinforced = t.structure_at(3, 1)
assert(reinforced.id == "reinforced_table", "a reinforced table stands beside it")
assert(reinforced.sprite == "reinforced_table-8",
    "joined west to the steel run, and not east to the wood: "
        .. tostring(reinforced.sprite))

-- And the wood. It ignores the reinforced table on its west and joins
-- the wooden one on its east, which is the asymmetry stated from the
-- side that proves it is a group rather than a material: same
-- mechanism, different word.
local wood = t.structure_at(4, 1)
assert(wood.id == "wood_table", "a wooden table stands beside the reinforced one")
assert(wood.sprite == "wood_table-4",
    "wood joins wood eastward and refuses steel westward: " .. tostring(wood.sprite))
assert(t.structure_at(5, 1).sprite == "wood_table-8",
    "and the far wooden one joins back: " .. tostring(t.structure_at(5, 1).sprite))

-- ---- two rods to a table, and back ----------------------------------
-- Everything within arm's reach of one tile, because the point is the
-- ladder and not the walking. The build site is the diagonal (2, 2).
t.world([==[(
    name: "workshop corner",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [
        (2, 1, "rod"),
        (1, 2, "metal"),
        (1, 1, "wrench"),
        (1, 1, "screwdriver"),
        (1, 1, "light_bulb"),
    ],
)]==], 7)

local p = t.join()
t.tick()

t.click(p, 2, 1, t.target_at(2, 1, "rod"))
t.run_ticks(2)
assert(t.hands(p).held == "rod", "rods in hand")

-- Armed, because rods make two things in this pack: a grille and a
-- table frame. A bare click takes the first in registry order, so a
-- spec that means the second says so exactly as the build menu does.
t.build(p, "rod", "table_frame", 2, 2)
t.run_seconds(1.5)
local frame = t.structure_at(2, 2)
assert(frame ~= nil and frame.id == "table_frame",
    "two rods and a second stand the frame up: " .. tostring(frame and frame.id))
assert(frame.sprite == "table_frame", "and it wears its own picture, not a junction")

-- A sheet over the frame is a table. tg picks WHICH table off the
-- stack (`get_table_type`); here the frame's own table says it.
t.swap_hands(p)
t.click(p, 1, 2, t.target_at(1, 2, "metal"))
t.run_ticks(2)
assert(t.hands(p).held == "metal", "sheets in the other hand")
t.click(p, 2, 2, t.target_at(2, 2, "table_frame"))
t.run_seconds(2.5)
local built = t.structure_at(2, 2)
assert(built ~= nil and built.id == "table",
    "the frame took the sheet: " .. tostring(built and built.id))
assert(built.sprite == "table-0",
    "and stands alone, so it wears the isolated frame: " .. tostring(built.sprite))

-- ---- what a table is FOR --------------------------------------------
-- A held thing clicked onto it lands on the pixel that was clicked, and
-- on no other. A bulb rather than a tool, deliberately: a screwdriver
-- clicked at a table is a screwdriver taking the table apart (the
-- table's own reaction table answers first, which is step 7 of the
-- interaction chain and tg's `attackby` order), and placement is what
-- happens when nothing else has anything to say. Both hands are full,
-- so the rods go on the deck first.
t.swap_hands(p)
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 1, t.target_at(1, 1, "light_bulb"))
t.run_ticks(2)
assert(t.hands(p).held == "light_bulb", "a bulb in the free hand")

t.click(p, 2, 2, t.target_at(2, 2, "table"), 7, -11)
t.run_ticks(2)
assert(t.hands(p).held == nil, "the bulb left the hand for the table")
local laid = t.item_at(2, 2, "light_bulb")
assert(laid ~= nil, "and it is lying on the table's tile")
assert(laid.offset.x == 7 and laid.offset.y == -11,
    "at the pixel that was clicked, with nothing added: "
        .. laid.offset.x .. "," .. laid.offset.y)

-- Put down again three pixels the other way: tg ASSIGNS the offset, so
-- the second placement is the second pixel and never the sum of both.
t.click(p, 2, 2, t.target_at(2, 2, "light_bulb"))
t.run_ticks(2)
assert(t.hands(p).held == "light_bulb", "picked back up off the table")
t.click(p, 2, 2, t.target_at(2, 2, "table"), -3, -4)
t.run_ticks(2)
local moved = t.item_at(2, 2, "light_bulb")
assert(moved.offset.x == -3 and moved.offset.y == -4,
    "moved, not accumulated: " .. moved.offset.x .. "," .. moved.offset.y)

-- The floor is not a table, which is the negative the whole flag exists
-- for: tg's turfs have no generic place branch, so a held thing clicked
-- at bare deck stays held.
t.click(p, 2, 2, t.target_at(2, 2, "light_bulb"))
t.run_ticks(2)
assert(t.hands(p).held == "light_bulb", "the bulb is in hand again")
t.click(p, 2, 1, nil, 7, -11)
t.run_ticks(2)
assert(t.hands(p).held == "light_bulb", "clicking bare deck puts nothing down")
assert(t.item_at(2, 1, "light_bulb") == nil, "the floor took nothing")
t.drop(p)
t.run_ticks(2)

-- ---- and back down again --------------------------------------------
-- Two ways out, and they differ by one thing: the driver lifts the top
-- off and leaves the frame, the ratchet takes the legs too
-- (tables_racks.dm:325-341).
t.click(p, 1, 1, t.target_at(1, 1, "screwdriver"))
t.run_ticks(2)
assert(t.hands(p).held == "screwdriver", "a driver in hand")
t.click(p, 2, 2, t.target_at(2, 2, "table"))
t.run_seconds(2.5)
local stripped = t.structure_at(2, 2)
assert(stripped ~= nil and stripped.id == "table_frame",
    "the top came off and the frame is still standing: "
        .. tostring(stripped and stripped.id))
assert(t.item_at(2, 2, "metal") ~= nil, "and the sheet is back on the deck")

-- Rebuild it, so the ratchet has something to take apart.
t.swap_hands(p)
assert(t.hands(p).held == "metal", "the rest of the stack is still in hand")
t.click(p, 2, 2, t.target_at(2, 2, "table_frame"))
t.run_seconds(2.5)
assert(t.structure_at(2, 2).id == "table", "a table again")

t.drop(p)
t.run_ticks(2)
t.click(p, 1, 1, t.target_at(1, 1, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "a ratchet in hand")
t.click(p, 2, 2, t.target_at(2, 2, "table"), 0, 0)
t.run_seconds(4.5)
assert(t.structure_at(2, 2) == nil, "the table came apart entirely")
assert(t.item_at(2, 2, "metal") ~= nil, "the sheet is on the deck")
assert(t.item_at(2, 2, "rod") ~= nil, "and so are the legs it stood on")
assert(t.hands(p).held == "wrench",
    "the ratchet is still a ratchet, not a thing left on a table")
