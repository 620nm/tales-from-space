-- The context menu grades a wall mount by its face, exactly as the click
-- does: in reach but behind the wall is no touch, so the primary row is
-- disclosed but graded out of range. The click half is proved in
-- diagonal_wall_mount_test.luau's "southwest face reach" room, whose map
-- this spec shares tile for tile.
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
