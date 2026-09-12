-- Wall-frame construction, refusal, transitions, and supporting-wall teardown.
-- Contract: the engine's docs/construction/mounts.md; diagonal placement and
-- button interactions are covered in diagonal_wall_mount_test.luau.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- A room with a corner in it: the builder stands at (1, 1) with a wall
-- to the north at (1, 0) and another to the west at (0, 1), which lets
-- the same tile carry independent brackets on two faces.
t.world([==[(
    name: "mount bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [
        (1, 1, "metal"),
        (1, 1, "cable_coil"),
        (1, 1, "wirecutters"),
        (1, 1, "welder"),
    ],
)]==], 7)

local p = t.join()
t.tick()

local function take(id)
    t.click(p, 1, 1, t.target_at(p, 1, 1, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function put_down()
    t.drop(p)
    t.run_ticks(2)
end

-- ---------------------------------------------------------------
-- THE REFUSALS COME FIRST, because each of them has to be earned
-- while there is still nothing hanging anywhere.
-- ---------------------------------------------------------------
take("metal")

-- A wall across the room never gets as far as the adjacency rule: a
-- build MENU placement is explicit intent, so the reach check answers
-- it first and in its own words. The anti-cheat claim survives either
-- way -- the tile the box would rise on is the server's record of
-- where the builder is standing, never the claim -- and it is the next
-- assertion that proves it, since the box lands underfoot rather than
-- wherever the click named.
local _ = t.messages(p)
ui_controls.build(p, "metal", "wall_frame", 3, 3)
t.run_seconds(4.5)
assert(said(p, "You can't reach that from here."), "a wall across the room is not one you stand at")
assert(t.structure_at(3, 3) == nil and t.structure_at(1, 1) == nil, "and nothing rose anywhere")

-- Bare floor is not a wall. `build.on` INVERTS on a mount -- it names
-- what the thing hangs ON -- so a floor tile offers no bracket at all
-- and the placement is refused rather than quietly landing somewhere.
local _ = t.messages(p)
ui_controls.build(p, "metal", "wall_frame", 2, 1)
t.run_seconds(4.5)
assert(said(p, "You can't build that there."), "nothing hangs off a floor tile")
assert(t.structure_at(2, 1) == nil, "and the floor stayed bare")
assert(t.structure_at(1, 1) == nil, "and nothing rose underfoot either")

-- ---------------------------------------------------------------
-- AND THE BRACKET ITSELF: on the BUILDER's tile, facing the wall,
-- with the wall left exactly as bare as it was.
-- ---------------------------------------------------------------
ui_controls.build(p, "metal", "wall_frame", 1, 0)
t.run_seconds(4.5)
local frame = t.structure_at(1, 1)
assert(frame ~= nil and frame.id == "wall_frame", "the box rises where the builder is standing")
assert(frame.state == "empty", "and it opens bare")
assert(frame.sprite == "wall_frame_n", "wearing the face that overhangs the wall it is bolted to")
assert(t.structure_at(1, 0) == nil, "and nothing whatever stands on the wall itself")

-- The same supporting face remains occupied.
local _ = t.messages(p)
ui_controls.build(p, "metal", "wall_frame", 1, 0)
t.run_seconds(4.5)
assert(said(p, "Something is already mounted here."), "the same face refuses a second bracket")
assert(t.structure_at(1, 1) ~= nil, "the original bracket remains present")

-- ---------------------------------------------------------------
-- THE LADDER, one rung, and the repaint that proves the facing rode
-- the state change: five lengths of cable and the box is wired, still
-- pointing at the same wall.
-- ---------------------------------------------------------------
put_down()
take("cable_coil")
t.click(p, 1, 1, t.target_at(p, 1, 1, "wall_frame"))
t.run_seconds(2.5)
assert(t.structure_at(1, 1).state == "wired", "five lengths of cable wire it")
assert(t.structure_at(1, 1).sprite == "wall_frame_wired_n",
    "and the new picture is still the one that faces the wall")

-- ...and backwards, because every rung of this ladder runs both ways.
put_down()
take("wirecutters")
t.click(p, 1, 1, t.target_at(p, 1, 1, "wall_frame"))
t.run_seconds(2.5)
assert(t.structure_at(1, 1).state == "empty", "the cutters take the wiring back out")
assert(t.count_items("cable_coil") > 0, "and hand the cable back")

-- ---------------------------------------------------------------
-- THE WALL SURVIVES WHAT IS BOLTED TO IT. A step a player CHOSE that
-- would stop this tile being a wall is refused by name, because
-- somebody is owed an answer (docs/CONSTRUCTION.md).
-- ---------------------------------------------------------------
put_down()
take("welder")
local _ = t.messages(p)
t.click_turf(p, 1, 0)
t.run_seconds(10.5)
assert(said(p, "Take the wall frame off the wall first."),
    "the wall names what is hanging on it")
assert(t.turf(1, 0) == "wall", "and stays a wall")

-- Take the box off and the same torch goes through. The frame is bare
-- again by now, which is the only state a torch will cut one off in.
t.click(p, 1, 1, t.target_at(p, 1, 1, "wall_frame"))
t.run_seconds(4.5)
assert(t.structure_at(1, 1) == nil, "the torch takes a bare frame off the wall")

t.click_turf(p, 1, 0)
t.run_seconds(10.5)
assert(t.turf(1, 0) ~= "wall", "and now the wall itself comes apart")
