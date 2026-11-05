-- A tile's ground material is drawn as its own matter part, read with
-- `t.seen_ground` (the engine's docs/looks/ground.md), and `t.seen_matter`
-- never lists it.
--
-- Columns 0-2 of the ground level are sand, columns 3-5 soil, over a
-- basement that only exists so a hole can be dug. Row 3 holds a tile of
-- named ground with no material and a blank tile: under the cold sky,
-- which names no material, neither has a face. A blank tile under a sky
-- that does name one is `environment_ground_test.luau`.
--
-- Where two grounds meet, the higher in the pack's `blending` precedence
-- (content/terrain.luau: sand over soil) keeps its edge and draws it over
-- an underlay part of the lower; the lower runs flat to the seam.
t.world(
    [==[(
    name: "ground face",
    needs: ["gravity"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(259.15)),
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

local SAND = "#D9C48F" -- content/substances/ground/sand.luau
local SOIL = "#5C4033" -- content/substances/ground/soil.luau

local p = t.join()
t.run_ticks(4)

-- A tile's ground: its one face, and the underlay parts under its edge.
local function ground_at(player: number, x: number, y: number): (SpecSeenMatterPart, { SpecSeenMatterPart })
    local body: SpecSeenMatterPart? = nil
    local underlays: { SpecSeenMatterPart } = {}
    for _, part in t.seen_ground(player, x, y) do
        if part.underlay then
            table.insert(underlays, part)
        else
            assert(body == nil, "tile (" .. x .. ", " .. y .. ") draws one ground face")
            body = part
        end
    end
    return assert(body, "tile (" .. x .. ", " .. y .. ") draws a ground face"), underlays
end

-- One ground part, in the material's own colour, and no matter beside it.
local function face(player: number, x: number, y: number): SpecSeenMatterPart
    local found, underlays = ground_at(player, x, y)
    assert(#underlays == 0, "tile (" .. x .. ", " .. y .. ") draws no underlay, got " .. #underlays)
    return found
end

local sand = face(p, 1, 1)
assert(sand.look == "ground_shell" and sand.phase == "solid", "the face is the profile's solid look")
assert(sand.tint == SAND, "a sand tile takes sand's colour, got " .. sand.tint)
assert(sand.amount == 255 and sand.alpha == 1, "a ground row is always at the maximum")
assert(face(p, 4, 1).tint == SOIL, "a soil tile takes soil's colour")
assert(#t.seen_matter(p, 1, 1) == 0, "the face is no cell matter: seen_matter lists none")

-- Two tiles of one ground join. The middle of the sand is one whole tile.
local middle_joins = assert(sand.joins, "the face is a shell")
assert(
    middle_joins.n and middle_joins.s and middle_joins.e and middle_joins.w and sand.whole,
    "sand among sand has no edge"
)

-- Two grounds that meet: sand outranks soil, so the sand keeps its edge on
-- its east side and draws a soil underlay under exactly those quadrants.
local seam, seam_underlays = ground_at(p, 2, 1)
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
assert(#seam_underlays == 1, "one underlay under the seam, got " .. #seam_underlays)
local under = seam_underlays[1]
assert(under.look == "ground_shell" and under.tint == SOIL, "the underlay is the soil's face, got " .. under.tint)
local under_drawn = assert(under.drawn, "an underlay fills only some quadrants")
assert(under_drawn.ne and under_drawn.se, "it fills the soil side")
assert(not under_drawn.nw and not under_drawn.sw, "and not the sand side")

-- The soil runs flat into the sand: no edge, no underlay.
local soil_seam = face(p, 3, 1)
local soil_seam_joins = assert(soil_seam.joins, "the face is a shell")
assert(soil_seam_joins.w and soil_seam.whole, "the lower soil joins the sand above it")
local soil_quadrants = assert(soil_seam.quadrants, "the face has quadrants")
assert(
    soil_quadrants.nw == "flat" and soil_quadrants.ne == "flat"
        and soil_quadrants.sw == "flat" and soil_quadrants.se == "flat",
    "the soil is flat to the seam"
)

-- Named ground with no material, and a blank tile, have no face.
assert(#t.seen_ground(p, 1, 3) == 0, "named ground that names no material draws none")
assert(#t.seen_ground(p, 4, 3) == 0, "a blank tile under a sky with no material draws none")

-- Digging the floor out from under a tile takes its face with it and does not
-- refuse: a ground can never block the dig.
assert(t.set_composition(2, 1, "bare", 0, "open"), "a tile on sand can be opened")
t.run_ticks(2)
assert(#t.seen_ground(p, 2, 1) == 0, "an opened tile has no face")
assert(#t.seen_ground(p, 1, 1) == 1, "its neighbours keep theirs")

-- Hinted ground blends as named ground does (tests/maps/ground_blend.ron):
-- sand hinted at x 0-1 beside the warm sky's soil, a wall at x 5 beside the
-- soil, and grass over moss on rows 3-5.
t.world_file("ground_blend.ron", 0, "free_build")
t.set_breathing(false)
local q = t.join()
t.run_ticks(4)

local hinted_seam, hinted_underlays = ground_at(q, 1, 1)
assert(hinted_seam.tint == SAND, "the hinted column is sand, got " .. hinted_seam.tint)
assert(not assert(hinted_seam.joins, "the face is a shell").e, "the hinted sand keeps its edge on the soil")
assert(
    #hinted_underlays == 1 and hinted_underlays[1].tint == SOIL,
    "and draws the soil under it, got " .. #hinted_underlays .. " underlays"
)
assert(face(q, 2, 1).whole, "the generated soil runs flat into the hinted sand")

-- A wall hides the ground under it: no face there, and the soil beside it is
-- flat toward it rather than edged as at a hole.
assert(#t.seen_ground(q, 5, 1) == 0, "the wall's tile draws no ground")
local by_wall = face(q, 4, 1)
assert(by_wall.tint == SOIL, "the tile beside the wall is soil, got " .. by_wall.tint)
assert(assert(by_wall.joins, "the face is a shell").e and by_wall.whole, "soil beside a wall is flat toward it")

-- Covers blend where their looks opt in: grass outranks moss, so the grass
-- keeps its edge over a moss underlay and the moss runs flat into the grass.
local function cover_parts(x: number, y: number, look: string): (SpecSeenMatterPart?, SpecSeenMatterPart?)
    local body: SpecSeenMatterPart? = nil
    local underlay: SpecSeenMatterPart? = nil
    for _, part in t.seen_matter(q, x, y) do
        if part.look == look then
            if part.underlay then
                underlay = part
            else
                body = part
            end
        end
    end
    return body, underlay
end

local grass, grass_own_underlay = cover_parts(2, 4, "grass")
local grass_body = assert(grass, "the grass draws at (2, 4)")
assert(grass_own_underlay == nil, "the grass draws no underlay of itself")
assert(not assert(grass_body.joins, "grass is a shell").e, "the grass keeps its edge on the moss")
local _, moss_under = cover_parts(2, 4, "moss")
local moss_underlay = assert(moss_under, "the grass tile draws the moss as its underlay")
local moss_drawn = assert(moss_underlay.drawn, "the underlay fills only the edge quadrants")
assert(moss_drawn.ne and moss_drawn.se and not moss_drawn.nw and not moss_drawn.sw, "on the moss side")
local moss, moss_own_underlay = cover_parts(3, 4, "moss")
local moss_body = assert(moss, "the moss draws at (3, 4)")
assert(moss_own_underlay == nil, "the lower moss draws no underlay")
assert(assert(moss_body.joins, "moss is a shell").w and moss_body.whole, "the moss runs flat into the grass")
