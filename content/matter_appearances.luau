-- Shared appearances for the one matter system. Profiles are
-- vocabulary; native aggregation chooses at most one liquid and one gas
-- look per visible tile, and one row per distinct solid look, from the
-- real phase/volume ledger (the engine's docs/looks/matter.md §4).
-- A rung is the amount at which a picture starts to draw (`at_ml` for
-- floor matter, `at_factor` for a gas); docs/looks/matter.md in the
-- engine is the contract. The art is assets/sprites/94-elemental.ron:
-- a `shell` names a strip, which bakes the five blocks `<strip>_0_0`
-- to `<strip>_0_4` the client stitches into joined edges.
--
-- The rungs are read off real spills (tests/matter_look/spill_ladder_test).
-- A tile is 1 m x 1 m x 3 m: a litre is a millimetre of wet, water stops
-- thinning at a 3.3 L film, and a puddle deeper than that is a flood.
-- Gas rungs are multiples of the substance's own visibility threshold.
return {
    defaults = {
        liquid = "puddle",
        solid = "powder",
        gas = "mist",
        -- What burns draws by what lies under the flame.
        burning = { gas = "flame_open", liquid = "flame_pool" },
    },
    profiles = {
        {
            key = "flame_open",
            visual_layer = "matter_flame",
            phase = "flame",
            full_kw = 2,
            alpha = { min = 0.6, max = 1 },
            light = { range = 4, power = 1.5, color = "#FFB060" },
            rungs = {
                { at_kw = 0.1, sprites = { "fire_gas_single_violent" } },
                { at_kw = 0.3, shell = { still = "fire_gas_smooth_violent" } },
            },
        },
        {
            key = "flame_pool",
            visual_layer = "matter_flame",
            phase = "flame",
            full_kw = 2,
            alpha = { min = 0.6, max = 1 },
            light = { range = 4, power = 1.5, color = "#FFB060" },
            rungs = {
                { at_kw = 0.1, sprites = { "fire_grease_single" } },
                { at_kw = 0.3, shell = { still = "fire_grease_smooth" } },
            },
        },
        {
            key = "puddle",
            visual_layer = "matter_ground",
            phase = "liquid",
            full_volume_ml = 1000,
            alpha = { min = 0.55, max = 0.95 },
            settle_seconds = 8,
            rungs = {
                { at_ml = 5, sprites = { "liquid_splatter_1", "liquid_splatter_2" } },
                { at_ml = 30, sprites = { "liquid_splash_1", "liquid_splash_2" } },
                { at_ml = 100, sprites = { "liquid_spill_1", "liquid_spill_2" } },
                {
                    at_ml = 250,
                    shell = { still = "liquid_puddle_smooth", moving = "liquid_puddle_smooth_shimmer" },
                },
                {
                    at_ml = 4500,
                    shell = { still = "liquid_pool_smooth_still", moving = "liquid_pool_smooth_ripple" },
                },
                -- Open water: 40 cm and deeper, as a 50 cm shallows stands
                -- well clear of it. One rung, so a shallower neighbour draws
                -- no surf between two tiles of the same sea.
                {
                    at_ml = 400000,
                    alone = true,
                    shade = 0.75,
                    shell = {
                        still = "ocean_body_smooth",
                        over = {
                            { strip = "ocean_backwash_smooth", tint = "#594936", edges_only = true },
                            { strip = "ocean_swash_smooth", tint = "#F4FAFF", edges_only = true },
                            { strip = "ocean_foam_lace_smooth", tint = "#F4FAFF", edges_only = true },
                        },
                    },
                },
            },
            weightless = {
                rungs = {
                    { at_ml = 5, sprites = { "liquid_zerog_small_float" } },
                    { at_ml = 250, sprites = { "liquid_zerog_mixed_float" } },
                    { at_ml = 2000, sprites = { "liquid_zerog_large_float" } },
                },
            },
        },
        {
            key = "powder",
            visual_layer = "matter_ground",
            phase = "solid",
            full_volume_ml = 50,
            alpha = { min = 0.25, max = 1.0 },
            rungs = {
                { at_ml = 1, sprites = { "solid_dusting_flour_single" } },
                { at_ml = 25, shell = { still = "solid_dusting_flour_smooth" } },
            },
        },
        {
            key = "granular",
            visual_layer = "matter_ground",
            phase = "solid",
            full_volume_ml = 50,
            rungs = {
                { at_ml = 1, sprites = { "solid_sprinkles" } },
                { at_ml = 25, sprites = { "solid_pile_small" } },
                { at_ml = 200, sprites = { "solid_pile_large" } },
            },
        },
        {
            key = "amorphous",
            visual_layer = "matter_ground",
            phase = "solid",
            full_volume_ml = 50,
            rungs = {
                { at_ml = 1, sprites = { "solid_soil_patch_single" } },
                { at_ml = 25, shell = { still = "solid_soil_smooth" } },
            },
        },
        {
            key = "crystalline",
            visual_layer = "matter_ground",
            phase = "solid",
            full_volume_ml = 50,
            rungs = {
                { at_ml = 1, sprites = { "solid_shards_small" } },
                { at_ml = 25, sprites = { "solid_shards_large" } },
                -- A sheet of it, standing in a bed.
                { at_ml = 400000, alone = true, shell = {
                    still = "terrain_ice_sheet_smooth",
                    flats = { "terrain_ice_sheet_smooth_0_4", "terrain_ice_sheet_flat_1",
                              "terrain_ice_sheet_flat_2", "terrain_ice_sheet_flat_3" },
                } },
            },
        },
        {
            key = "chunks",
            visual_layer = "matter_ground",
            phase = "solid",
            full_volume_ml = 50,
            rungs = {
                { at_ml = 1, sprites = { "solid_scattering" } },
                { at_ml = 25, shell = { still = "solid_debris_jagged_smooth" } },
            },
        },
        -- What a tile's ground material draws as (content/terrain.luau
        -- `face`). Not measured from the cell: the engine fixes a ground
        -- row's amount at the maximum, so the one rung always shows and
        -- alpha sits at full. The `ground_face` layer puts it over the
        -- substrate and under decals, residue and everything on the tile.
        -- The art is greyscale and takes the material's colour as tint.
        {
            key = "ground_shell",
            visual_layer = "ground_face",
            phase = "solid",
            alpha = { min = 1, max = 1 },
            rungs = {
                { at_ml = 1, shell = {
                    still = "terrain_silicate_rough_smooth",
                    flats = { "terrain_silicate_rough_smooth_0_4", "terrain_silicate_rough_flat_1",
                              "terrain_silicate_rough_flat_2", "terrain_silicate_rough_flat_3" },
                } },
            },
        },
        {
            key = "mist",
            visual_layer = "gas_haze",
            phase = "gas",
            alpha = { min = 0.08, max = 0.8 },
            wind = { at_mps = { 0.03, 0.25 }, calm_ratio = 0.8 },
            streak = { sprite = "wind_streak", full_alpha_mps = 1 },
            rungs = {
                {
                    at_factor = 1,
                    shell = {
                        still = "gas_mist_smooth_still",
                        moving = { "gas_mist_smooth_gentle", "gas_mist_smooth_stirred" },
                    },
                },
            },
        },
        {
            key = "smoke",
            visual_layer = "gas_haze",
            phase = "gas",
            alpha = { min = 0.08, max = 0.9 },
            wind = { at_mps = { 0.03, 0.25 }, calm_ratio = 0.8 },
            streak = { sprite = "wind_streak", full_alpha_mps = 1 },
            rungs = {
                {
                    at_factor = 1,
                    shell = {
                        still = "gas_mist_smooth_still",
                        moving = { "gas_mist_smooth_gentle", "gas_mist_smooth_stirred" },
                    },
                },
                {
                    at_factor = 10,
                    shell = {
                        still = "gas_smoke_smooth_still",
                        moving = { "gas_smoke_smooth_gentle", "gas_smoke_smooth_stirred" },
                    },
                },
            },
        },
        {
            key = "cloud",
            visual_layer = "gas_haze",
            phase = "gas",
            alpha = { min = 0.08, max = 1.0 },
            wind = { at_mps = { 0.03, 0.25 }, calm_ratio = 0.8 },
            streak = { sprite = "wind_streak", full_alpha_mps = 1 },
            rungs = {
                {
                    at_factor = 1,
                    shell = {
                        still = "gas_mist_smooth_still",
                        moving = { "gas_mist_smooth_gentle", "gas_mist_smooth_stirred" },
                    },
                },
                {
                    at_factor = 10,
                    shell = {
                        still = "gas_smoke_smooth_still",
                        moving = { "gas_smoke_smooth_gentle", "gas_smoke_smooth_stirred" },
                    },
                },
                {
                    at_factor = 30,
                    shell = {
                        still = "gas_cloud_smooth_still",
                        moving = { "gas_cloud_smooth_gentle", "gas_cloud_smooth_stirred" },
                    },
                },
            },
        },
    },
}
