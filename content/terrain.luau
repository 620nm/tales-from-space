-- How a condensed phase of ground reads, and the covers a map lays on it
-- (the engine's docs/content-schema/terrain.md). A tile names a ground material, a
-- blend; the profile that blend gets says which substrate component a
-- tile over a block of it carries (`floor`), which matter look is drawn as
-- the face (`face`, in matter_appearances.luau) and how much darker that
-- floor's own picture shows at a shell's edge (`under_shade`).
--
-- 0.7 is the art's `silicate_low` over its `silicate` (#82402A over
-- #B85C3C in tools/art/terrestrial/schema_contract.py), so an edge pixel
-- reads as the ledge the art drew. A profile with no `face_tint` takes
-- its material's own colour, so ice, basalt and soil read apart.
--
-- The liquid and ice profiles stand real matter in a bed (`fill`,
-- `depth_m`): a bed of 1.5 m of a 3 m tile is safe under a body's pressure
-- bands. A sea does not evaporate (`evaporation = 0`), or every tile of it
-- would stay awake for good, and ignores a level difference under a
-- millimetre. A seabed shows sand under the liquid (`face_tint`).
local SEABED = "#CBB68C"

return {
    defaults = { solid = "bare_ground", liquid = "deep_liquid" },
    profiles = {
        {
            key = "bare_ground",
            phase = "solid",
            floor = "ground",
            face = "ground_shell",
            under_shade = 0.7,
        },
        {
            key = "deep_liquid",
            phase = "liquid",
            floor = "ground",
            face = "ground_shell",
            face_tint = SEABED,
            fill = true,
            depth_m = 1.5,
            evaporation = 0,
            rest_head_m = 0.001,
            ideal = { half_life_s = 120 },
        },
        -- The sea's own shore: `deep_liquid` half a metre deep
        -- (blends/sea_shallows.luau).
        {
            key = "shallows",
            phase = "liquid",
            floor = "ground",
            face = "ground_shell",
            face_tint = SEABED,
            fill = true,
            depth_m = 0.5,
            evaporation = 0,
            rest_head_m = 0.001,
            ideal = { half_life_s = 120 },
        },
        {
            key = "still_liquid",
            phase = "liquid",
            floor = "ground",
            face = "ground_shell",
            face_tint = SEABED,
            fill = true,
            depth_m = 1,
            rest_head_m = 0.001,
        },
        -- Ice draws its own sheet, tinted by the ice itself.
        {
            key = "sheet_ice",
            phase = "solid",
            floor = "ice_floor",
            face = "ice_shell",
            under_shade = 0.7,
            fill = true,
            depth_m = 1,
            evaporation = 0,
        },
        -- A cliff: the `cliff` floor blocks a body, and the face draws
        -- the stepped escarpment, joined to the cliff beside it.
        {
            key = "cliff",
            phase = "solid",
            floor = "cliff",
            face = "cliff_shell",
            under_shade = 0.7,
        },
        -- A bed dug and left dry: whatever it reaches runs in.
        {
            key = "dry_bed",
            phase = "solid",
            floor = "ground",
            face = "ground_shell",
            under_shade = 0.7,
            depth_m = 2,
        },
    },
    -- Plants a map lays on a column's surface tile (`ground.cover`): real
    -- dry plant matter in the tile's cell beside the air, drawn by the
    -- substance's own look and burnt by reactions/{grass,moss}_fire.luau.
    -- 300 g of grass a square metre, a temperate grassland's standing crop,
    -- and 200 g of moss (chosen figures): about a litre a tile at grass's
    -- 0.3 g/mL and moss's 0.2 (substances/plants/).
    covers = {
        {
            id = "grass",
            label = "lunatic/tfs:ground.cover.grass",
            substance = "grass:solid",
            kg_per_m2 = 0.3,
        },
        {
            id = "moss",
            label = "lunatic/tfs:ground.cover.moss",
            substance = "moss:solid",
            kg_per_m2 = 0.2,
        },
    },
}
