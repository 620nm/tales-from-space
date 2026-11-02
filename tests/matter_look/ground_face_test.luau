-- A tile's ground material is drawn as its own matter part, read with
-- `t.seen_ground` (the engine's docs/looks/ground.md), and `t.seen_matter`
-- never lists it.
--
-- Columns 0-2 of the ground level are sand, columns 3-5 soil, over a
-- basement that only exists so a hole can be dug. Row 3 holds a tile of
-- named ground with no material and a blank tile: under the cold sky,
-- which names no material, neither has a face. (No mode rolls
-- `warm_outdoors` or `mars_surface` yet, so a spec cannot stand under a
-- sky whose `material` a blank tile would inherit.)
t.world(
    [==[(
    name: "ground face",
    tags: ["terrestrial"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        'f': (composition: (substrate: Named("rock_floor"))),
        'a': (composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        's': (composition: (substrate: Named("ground"), material: Named("soil_ground"), components: [])),
        'b': (composition: (substrate: Named("ground"))),
        'c': (composition: ()),
    },
    levels: [
        (
            rows: [
                "ffffff",
                "ffffff",
                "ffffff",
                "ffffff",
            ],
            structures: [],
        ),
        (
            rows: [
                "aaasss",
                "aaasss",
                "aaasss",
                "bbbccc",
            ],
            structures: [(0, 0, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local SAND = "#D9C48F" -- content/substances/sand.luau
local SOIL = "#5C4033" -- content/substances/soil.luau

local p = t.join()
t.run_ticks(4)

-- One ground part, in the material's own colour, and no matter beside it.
local function face(x: number, y: number): SpecSeenMatterPart
    local parts = t.seen_ground(p, x, y)
    assert(#parts == 1, "tile (" .. x .. ", " .. y .. ") draws one ground part, got " .. #parts)
    return parts[1]
end

local sand = face(1, 1)
assert(sand.look == "ground_shell" and sand.phase == "solid", "the face is the profile's solid look")
assert(sand.tint == SAND, "a sand tile takes sand's colour, got " .. sand.tint)
assert(sand.amount == 255 and sand.alpha == 1, "a ground row is always at the maximum")
assert(face(4, 1).tint == SOIL, "a soil tile takes soil's colour")
assert(#t.seen_matter(p, 1, 1) == 0, "the face is no cell matter: seen_matter lists none")

-- Two tiles of one ground join. The middle of the sand is one whole tile.
local middle_joins = assert(sand.joins, "the face is a shell")
assert(
    middle_joins.n and middle_joins.s and middle_joins.e and middle_joins.w and sand.whole,
    "sand among sand has no edge"
)

-- Two grounds that meet draw an edge: sand's east side meets soil.
local seam = face(2, 1)
local seam_joins = assert(seam.joins, "the face is a shell")
assert(seam_joins.n and seam_joins.s and seam_joins.w, "the seam tile still joins sand on three sides")
assert(not seam_joins.e, "and not the soil beside it")
local seam_quadrants = assert(seam.quadrants, "the face has quadrants")
assert(
    seam_quadrants.nw == "flat" and seam_quadrants.sw == "flat",
    "the sand side stays flush"
)
assert(
    seam_quadrants.ne == "vertical" and seam_quadrants.se == "vertical",
    "the soil side rounds off along the seam"
)
local soil_seam_joins = assert(face(3, 1).joins, "the face is a shell")
assert(not soil_seam_joins.w, "the soil tile does not join the sand either")

-- Named ground with no material, and a blank tile, have no face.
assert(#t.seen_ground(p, 1, 3) == 0, "named ground that names no material draws none")
assert(#t.seen_ground(p, 4, 3) == 0, "a blank tile under a sky with no material draws none")

-- Digging the floor out from under a tile takes its face with it and does not
-- refuse: a ground can never block the dig.
assert(t.set_composition(2, 1, "bare", 0, "open"), "a tile on sand can be opened")
t.run_ticks(2)
assert(#t.seen_ground(p, 2, 1) == 0, "an opened tile has no face")
assert(#t.seen_ground(p, 1, 1) == 1, "its neighbours keep theirs")
