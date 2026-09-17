-- The context menu grades a wall mount by its face, exactly as the click
-- does: in reach but behind the wall is no touch, so the primary row is
-- disclosed but graded out of range. The click half is proved in
-- diagonal_wall_mount_test.luau's "southwest face reach" room, whose map
-- this spec shares tile for tile. The press wants an empty hand, so the
-- spray bottle on the spawn tile waits until the press pins stand: held,
-- the shut face offers no primary at all, the open face offers the
-- bottle's own row, and far down the hall that row offers past the
-- mount, as the far click would spray.
t.world(
    [==[(
    name: "southwest face hints",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),

        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),

    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "##..#",
        "#####",
    ],
    structures: [
        (2, 1, "player_spawn"),
        (2, 2, "airlock_button", { "mount": "southwest" }),
    ],
    items: [(2, 1, "spray_bottle")],
)]==],
    0
)

local p = t.join()
t.run_ticks(4)

type Step = "east" | "north" | "south" | "west"

local function walk(dir: Step)
    t.move(p, dir)
    t.run_ticks(5)
end

local function primary()
    local target = assert(t.target_at(p, 2, 2, "airlock_button"), "the button stays visible")
    for _, row in ipairs(t.action_hints(p, target)) do
        if row.gesture == "primary" then
            return row
        end
    end
    error("the button discloses a primary row")
end

local function held_spray()
    local target = assert(t.target_at(p, 2, 2, "airlock_button"), "the button stays visible")
    for _, row in ipairs(t.action_hints(p, target)) do
        if row.id == "spray" then
            return row
        end
    end
    error("the held bottle discloses its spray row")
end

local px, py = t.pos(p)
assert(px == 2 and py == 1, "the player starts north of the southwest button")
local shut = primary()
assert(shut.id == "press", "the primary row is the button press")
assert(
    shut.label.key == "lunatic/tfs:ui.affordance.press",
    "the primary row carries the press label"
)
assert(shut.available == false, "the shut face grades its primary out of range")

walk("west")
walk("south")
px, py = t.pos(p)
assert(px == 1 and py == 2, "the player stands west of the southwest button")
assert(primary().available == true, "the open face offers its primary")

walk("east")
px, py = t.pos(p)
assert(px == 2 and py == 2, "the player stands on the button tile")
assert(primary().available == true, "the mount's own tile is its open face")

-- The same two faces with the bottle held: the shut face offers no
-- primary at all, while the open face offers the held row in reach.
walk("north")
px, py = t.pos(p)
assert(px == 2 and py == 1, "the player steps back north of the button")
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "spray_bottle")))
t.run_ticks(2)
local shut_held = held_spray()
assert(shut_held.available == false, "the shut face grades the held row out of range")
for _, row in ipairs(t.action_hints(p, assert(t.target_at(p, 2, 2, "airlock_button")))) do
    assert(
        not (row.gesture == "primary" and row.available),
        "the shut face offers no primary, ranged tool or none"
    )
end

walk("west")
walk("south")
px, py = t.pos(p)
assert(px == 1 and py == 2, "the player stands west of the southwest button again")
assert(held_spray().available == true, "the open face offers the held row")

-- Far down the hall the mount is no bar at all: far clicks route to the
-- ranged claim past no face gate, so the held bottle's row offers.
t.world(
    [==[(
    name: "southwest face hints at range",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),

        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),

    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "##....##",
        "########",
    ],
    structures: [
        (2, 1, "player_spawn"),
        (2, 2, "airlock_button", { "mount": "southwest" }),
    ],
    items: [(2, 1, "spray_bottle")],
)]==],
    0
)
p = t.join()
t.run_ticks(4)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "spray_bottle")))
t.run_ticks(2)

walk("east")
walk("east")
walk("east")
px, py = t.pos(p)
assert(px == 5 and py == 1, "the player stands three tiles down the hall")
local far_target = assert(t.target_at(p, 2, 2, "airlock_button"), "the button stays visible at range")
local spray = nil
for _, row in ipairs(t.action_hints(p, far_target)) do
    if row.id == "spray" then
        spray = row
    end
end
assert(spray ~= nil and spray.available, "the ranged row offers past a far mount")
