-- A blank tile reads its ground from the sky it stands under: the tag rolls
-- `warm_outdoors`, whose `material` is soil. Only a tile that inherits its
-- substrate inherits the material; a tile can still say it has none, or
-- name its own.
t.world(
    [==[(
    name: "environment ground",
    tags: ["terrestrial", "warm_outdoors"],
    environment: (kind: Exact(terrestrial)),
    legend: {
        'c': (composition: ()),
        'n': (composition: (material: None)),
        'b': (composition: (substrate: Named("ground"))),
        'a': (composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
    },
    levels: [
        (
            rows: [
                "cccccc",
                "cccccc",
                "cccccc",
                "nnbbaa",
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

local function face(x: number, y: number): SpecSeenMatterPart
    local parts = t.seen_ground(p, x, y)
    assert(#parts == 1, "tile (" .. x .. ", " .. y .. ") draws one ground part, got " .. #parts)
    return parts[1]
end

local blank = face(2, 1)
assert(blank.tint == SOIL, "a blank tile takes the sky's material, got " .. blank.tint)
assert(blank.look == "ground_shell", "through the same profile a named material takes")
assert(blank.whole, "two blank tiles are one ground: no edge between them")
assert(#t.seen_matter(p, 2, 1) == 0, "inherited ground is no cell matter either")

assert(#t.seen_ground(p, 0, 3) == 0, "a tile that says it has no material draws none")
assert(#t.seen_ground(p, 2, 3) == 0, "a named substrate does not inherit the sky's material")
assert(face(4, 3).tint == SAND, "a named material outranks the sky's")
