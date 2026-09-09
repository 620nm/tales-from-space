-- The two-tile airlock: one leaf, two tiles, and a window in it.
--
-- tg's /obj/machinery/door/airlock/multi_tile
-- (code/game/machinery/doors/airlock.dm:2581-2607) is one door object
-- with an invisible filler standing on the tile beside it
-- (`set_filler`, code/game/machinery/doors/door.dm:198-208), so every
-- question about the second tile is a question about the first. Here
-- that is a footprint, and this spec asks the second tile every
-- question a player could: what stands there, is it shut, may I walk
-- through it, will it close on me, and CAN I SEE THROUGH IT.
--
-- The last one is why the plain leaf at (7, 3) is in the map. A glazed
-- door that sees through is only worth proving beside a solid one that
-- does not: tg's whole difference between the two is `opacity = FALSE`
-- (airlock.dm:2280-2283), and this sheet has no solid version at all
-- (multi_tile/public/glass.dmi ships no `fill_` states), so the wide
-- leaf is glazed by construction.
--
--   y1  # a  .  .  L  .  .  L  g #      L = locker, behind each door
--   y2  # .  .  .  .  .  .  .  . #
--   y3  # #  #  W  W  #  #  S  # #      W = the wide leaf, S = a plain one
--   y4  # .  .  .  .  .  .  .  . #
--   y5  # .  .  .  .  .  .  .  . #

local ROOM = [==[(
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
    spawns: [(4, 5)],
    structures: [
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
)]==]

t.world(ROOM, 7)
local p = t.join()
t.run_ticks(4)

local function step(dir)
    t.move(p, dir)
    t.run_ticks(5) -- a step is rate-limited; give the cooldown room
    return t.pos(p)
end

-- ---------------------------------------------------------------
-- One leaf, two tiles. Both answer as the body, and the tile past
-- the far edge answers as nothing.
-- ---------------------------------------------------------------
for _, at in ipairs({ { 3, 3 }, { 4, 3 } }) do
    local it = t.structure_at(at[1], at[2])
    assert(it and it.id == "airlock_wide",
        ("(%d, %d) is the wide leaf, got %s"):format(at[1], at[2], tostring(it and it.id)))
end
assert(t.structure_at(4, 4) == nil, "the tile south of it is bare floor")

-- Half a doorway per tile, and the east half names the west half as
-- its body: one door drawn across two atlas cells, not two doors.
local body = t.target_at(3, 3, "airlock_wide")
local east = t.target_at(4, 3, "airlock_wide")
assert(body and east and body ~= east, "the east tile is a cell with a wire id of its own")

local west_seen = t.seen(p, body)
local east_seen = t.seen(p, east)
assert(west_seen.layers[1].sprite == "door_wide_l",
    "the west half wears the west picture, got " .. tostring(west_seen.layers[1].sprite))
assert(east_seen.layers[1].sprite == "door_wide_r",
    "and the east half the east one, got " .. tostring(east_seen.layers[1].sprite))
assert(east_seen.extent_of == body, "which belongs to the leaf standing west of it")
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
step("north") -- (4, 4), square on the east half of the wide leaf
local through_glass = t.seen(p, t.target_at(4, 1, "locker"))
assert(through_glass.kind ~= "unseen",
    "the locker beyond the shut glazed leaf is in sight, got " .. through_glass.kind)

local behind_steel = t.seen(p, t.target_at(7, 1, "locker"))
assert(behind_steel.kind == "unseen",
    "and the one behind the shut solid leaf is not, got " .. behind_steel.kind)

-- ---------------------------------------------------------------
-- Bumping the EAST tile works the door -- the whole door.
-- ---------------------------------------------------------------
local x, y = step("north")
assert(x == 4 and y == 4, "a shut leaf is a shut leaf from either half")
t.run_ticks(15) -- tg's airlock takes 0.6 s to swing; let it finish
assert(t.door_at(3, 3).open, "bumping the east tile opened the whole leaf")
assert(t.door_at(4, 3).open, "including the tile that was bumped")

x, y = step("north")
assert(x == 4 and y == 3, "and you walk through the half you opened")

-- ---------------------------------------------------------------
-- It will not close on somebody standing in the SECOND tile. tg
-- checks every turf the leaf covers (`for(var/turf/checked_turf in
-- locs)`, airlock.dm:1420-1430) and so does this.
-- ---------------------------------------------------------------
t.run_ticks(90) -- well past the autoclose delay
assert(t.door_at(3, 3).open, "the leaf stayed open with a man in its east half")

x, y = step("north")
assert(x == 4 and y == 2, "step clear of the doorway")
t.run_ticks(90)
assert(not t.door_at(3, 3).open, "and once the doorway is empty it shuts itself")
assert(not t.door_at(4, 3).open, "both halves of it")
