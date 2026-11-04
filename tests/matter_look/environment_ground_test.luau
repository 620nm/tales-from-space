-- A blank tile shows the ground generated under it: the map's surface
-- temperature picks `warm_outdoors`, whose `ground` tops each column with
-- soil. A tile that names its own substrate or material keeps it.
t.world(
    [==[(
    name: "environment ground",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(293.15)),
    legend: {
        'c': (composition: ()),
        'b': (composition: (substrate: Named("ground"))),
        'a': (composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
    },
    levels: [
        (
            rows: [
                "cccccc",
                "cccccc",
                "cccccc",
                "ccbbaa",
            ],
            structures: [(0, 0, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local SOIL = "#5C4033" -- content/substances/ground/soil.luau
local SAND = "#D9C48F" -- content/substances/ground/sand.luau

local p = t.join()
t.run_ticks(4)

assert(t.environment().id == "warm_outdoors", "293.15 K picks the warm ground, got " .. t.environment().id)

local function face(x: number, y: number): SpecSeenMatterPart
    local parts = t.seen_ground(p, x, y)
    assert(#parts == 1, "tile (" .. x .. ", " .. y .. ") draws one ground part, got " .. #parts)
    return parts[1]
end

local blank = face(2, 1)
assert(blank.tint == SOIL, "a blank tile shows the soil block under it, got " .. blank.tint)
assert(blank.look == "ground_shell", "through the same profile a named material takes")
assert(blank.whole, "two blank tiles over one ground: no edge between them")
assert(#t.seen_matter(p, 2, 1) == 0, "generated ground is no cell matter either")

assert(#t.seen_ground(p, 2, 3) == 0, "a named substrate with no material draws no ground")
assert(face(4, 3).tint == SAND, "a named material outranks the generated ground")
