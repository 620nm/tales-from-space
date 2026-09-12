-- The two-tile airlock: one leaf, two tiles, a window in it, and the
-- two ways it can stand.
--
-- tg's /obj/machinery/door/airlock/multi_tile
-- (code/game/machinery/doors/airlock.dm:2581-2607) is one door object
-- with an invisible filler standing on the tile beside it -- east of a
-- leaf facing north or south, north of one facing east or west
-- (`set_filler` and `n(dir)`, code/game/machinery/doors/door.dm:198-208)
-- -- so every question about the second tile is a question about the
-- first. Here that is one entry with a `footprint` and two `facings`,
-- and this spec asks the second tile every question a player could:
-- what stands there, is it shut, may I walk through it, will it close
-- on me, and CAN I SEE THROUGH IT.
--
-- It asks all of them TWICE, once per facing, because a turn moves the
-- cells and the pictures both and either could be got wrong on its own.
--
-- The last one is why a plain leaf stands beside the wide one in the
-- first map. A glazed door that sees through is only worth proving
-- beside a solid one that does not: tg's whole difference between the
-- two is `opacity = FALSE` (airlock.dm:2280-2283), and this sheet has no
-- solid version at all (multi_tile/public/glass.dmi ships no `fill_`
-- states), so the wide leaf is glazed by construction.

local function step(p, dir)
    t.move(p, dir)
    t.run_ticks(5) -- a step is rate-limited; give the cooldown room
    return t.pos(p)
end

-- ===============================================================
-- EAST TO WEST. Two tiles side by side in a wall that runs across.
--
--   y1  # a  .  .  L  .  .  L  g #      L = locker, behind each door
--   y2  # .  .  .  .  .  .  .  . #
--   y3  # #  #  W  W  #  #  S  # #      W = the wide leaf, S = a plain one
--   y4  # .  .  .  .  .  .  .  . #
--   y5  # .  .  .  .  .  .  .  . #
-- ===============================================================
t.world([==[(
    name: "wide doorway",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "##########",
        "#a......g#",
        "#........#",
        "###..##.##",
        "#........#",
        "#........#",
        "##########",
    ],
    structures: [
        (4, 5, "player_spawn"),
        (3, 3, "airlock_wide"),
        (7, 3, "airlock"),
        (4, 1, "locker"),
        (7, 1, "locker"),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (6, 1, 3), (7, 1, 3), (8, 1, 3),
        (3, 2, 3), (7, 2, 3),
        (3, 3, 3), (7, 3, 3),
    ],
)]==], 7)
local p = t.join()
t.run_ticks(4)

-- ---------------------------------------------------------------
-- One leaf, two tiles. Both answer as the body, and the tile south
-- of it answers as nothing.
-- ---------------------------------------------------------------
for _, at in ipairs({ { 3, 3 }, { 4, 3 } }) do
    local it = t.structure_at(at[1], at[2])
    assert(it and it.id == "airlock_wide",
        ("(%d, %d) is the wide leaf, got %s"):format(at[1], at[2], tostring(it and it.id)))
end
assert(t.structure_at(4, 4) == nil, "the tile south of it is bare floor")

-- Half a doorway per tile, and the east half names the west half as
-- its body: one door drawn across two atlas cells, not two doors.
local body = t.target_at(p, 3, 3, "airlock_wide")
local east = t.target_at(p, 4, 3, "airlock_wide")
assert(body and east and body ~= east, "the east tile is a cell with a wire id of its own")

local west_seen = t.seen(p, body)
local east_seen = t.seen(p, east)
assert(west_seen.layers[1].sprite == "door_wide_w",
    "the west half wears the west picture, got " .. tostring(west_seen.layers[1].sprite))
assert(east_seen.layers[1].sprite == "door_wide_e",
    "and the east half the east one, got " .. tostring(east_seen.layers[1].sprite))
assert(t.same_target(east_seen.extent_of, body), "which belongs to the leaf standing west of it")
assert(east_seen.kind == "door",
    "and streams as a DOOR, so the client predicts it like one: " .. tostring(east_seen.kind))

-- ---------------------------------------------------------------
-- Both tiles are the same door, shut and live.
-- ---------------------------------------------------------------
for _, at in ipairs({ { 3, 3 }, { 4, 3 } }) do
    local d = t.door_at(at[1], at[2])
    assert(d ~= nil, ("(%d, %d) answers as a door"):format(at[1], at[2]))
    assert(not d.open, "shut")
    assert(d.powered, "and on the room circuit")
end

-- ---------------------------------------------------------------
-- IT DOES NOT OBSTRUCT LINE OF SIGHT. Shut, from the corridor, the
-- locker on the far side of the glazed leaf is visible through it --
-- through the EAST tile, which is the half that would be forgotten.
-- The plain leaf three tiles along is the control: same corridor,
-- same distance, and nothing to see.
-- ---------------------------------------------------------------
step(p, "north") -- (4, 4), square on the east half of the wide leaf
assert(t.seen(p, t.target_at(p, 4, 1, "locker")).kind ~= "unseen",
    "the locker beyond the shut glazed leaf is in sight")
assert(t.target_at(p, 7, 1, "locker") == nil,
    "and the one behind the shut solid leaf is not")

-- ---------------------------------------------------------------
-- Bumping the EAST tile works the door -- the whole door.
-- ---------------------------------------------------------------
local x, y = step(p, "north")
assert(x == 4 and y == 4, "a shut leaf is a shut leaf from either half")
t.run_ticks(15) -- tg's airlock takes 0.6 s to swing; let it finish
assert(t.door_at(3, 3).open, "bumping the east tile opened the whole leaf")
assert(t.door_at(4, 3).open, "including the tile that was bumped")

x, y = step(p, "north")
assert(x == 4 and y == 3, "and you walk through the half you opened")

-- ---------------------------------------------------------------
-- It will not close on somebody standing in the SECOND tile. tg
-- checks every turf the leaf covers (`for(var/turf/checked_turf in
-- locs)`, airlock.dm:1420-1430) and so does this.
-- ---------------------------------------------------------------
t.run_ticks(90) -- well past the autoclose delay
assert(t.door_at(3, 3).open, "the leaf stayed open with a man in its east half")

x, y = step(p, "north")
assert(x == 4 and y == 2, "step clear of the doorway")
t.run_ticks(90)
assert(not t.door_at(3, 3).open, "and once the doorway is empty it shuts itself")
assert(not t.door_at(4, 3).open, "both halves of it")

-- ===============================================================
-- NORTH TO SOUTH. The SAME entry in a wall that runs down the map,
-- turned: `dir = "east"` is three clockwise quarters off the south the
-- footprint was authored in, so the second cell walks from one step
-- east to one step NORTH (docs/content-schema/facings.md). The anchor a
-- map names stays the anchor -- here the SOUTH tile of the pair.
--
--   y1  # a  .  #  .  .  #
--   y2  # .  .  N  .  .  #      N = the north half
--   y3  # .  .  S  .  L  #      S = the anchor, L = a locker
--   y4  # g  .  #  .  .  #
-- ===============================================================
t.world([==[(
    name: "upright doorway",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#a.#..#",
        "#.....#",
        "#.....#",
        "#g.#..#",
        "#######",
    ],
    structures: [
        (1, 3, "player_spawn"),
        (3, 3, "airlock_wide", { "dir": "east" }),
        (5, 3, "locker"),
    ],
    cables: [
        (1, 1, 3), (1, 2, 3), (1, 3, 3), (1, 4, 3),
        (2, 3, 3), (3, 3, 3),
    ],
)]==], 7)
local q = t.join()
t.run_ticks(4)

for _, at in ipairs({ { 3, 3 }, { 3, 2 } }) do
    local it = t.structure_at(at[1], at[2])
    assert(it and it.id == "airlock_wide",
        ("(%d, %d) is the upright leaf, got %s"):format(at[1], at[2], tostring(it and it.id)))
end

-- The turn moves the PICTURES too, and they are not the resting ones
-- rotated: tg draws the east-facing door down the left of its 64x64
-- cell and the south-facing one across the bottom, two drawings, and
-- the entry says which cell wears which per facing.
local anchor = t.target_at(q, 3, 3, "airlock_wide")
local north = t.target_at(q, 3, 2, "airlock_wide")
assert(t.seen(q, anchor).layers[1].sprite == "door_wide_s",
    "the south half wears the south picture, got "
        .. tostring(t.seen(q, anchor).layers[1].sprite))
assert(t.seen(q, north).layers[1].sprite == "door_wide_n",
    "and the north half the north one, got "
        .. tostring(t.seen(q, north).layers[1].sprite))
assert(t.same_target(t.seen(q, north).extent_of, anchor), "one body, laid from its south tile")

for _, at in ipairs({ { 3, 3 }, { 3, 2 } }) do
    local d = t.door_at(at[1], at[2])
    assert(d ~= nil and not d.open and d.powered,
        ("(%d, %d) is the same shut, live door"):format(at[1], at[2]))
end

-- Glazed the same way round: the locker across the shut leaf is in
-- sight from the corridor west of it.
assert(t.seen(q, t.target_at(q, 5, 3, "locker")).kind ~= "unseen",
    "the upright leaf sees through too")

-- ...and bumping its NORTH half opens the whole thing.
local qx, qy = step(q, "north")
assert(qx == 1 and qy == 2, "up the west corridor")
qx, qy = step(q, "east")
assert(qx == 2 and qy == 2, "beside the north half")
qx, qy = step(q, "east")
assert(qx == 2 and qy == 2, "which is shut")
t.run_ticks(15)
assert(t.door_at(3, 3).open, "and bumping it opened the leaf its body stands south of")
qx, qy = step(q, "east")
assert(qx == 3 and qy == 2, "so you walk through the half you bumped")
