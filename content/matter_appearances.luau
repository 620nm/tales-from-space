-- Shared floor appearances for the one matter system. Profiles are
-- vocabulary; native aggregation chooses at most one liquid and one
-- solid layer per visible tile from the real phase/volume ledger.
return {
    defaults = {
        liquid = "liquid",
        solid = "powder",
    },
    profiles = {
        {
            key = "liquid",
            phase = "liquid",
            full_volume_ml = 50,
            alpha = { min = 0.15, max = 0.80 },
            tiers = {
                {
                    at_ml = 1,
                    sprites = {
                        "matter_liquid_1", "matter_liquid_2", "matter_liquid_3",
                        "matter_liquid_5", "matter_liquid_6",
                    },
                },
            },
        },
        -- WATER, and anything else that pools by the litre. The shared
        -- `liquid` profile above tops out at a fifty-millilitre splash,
        -- which is a beaker emptied on the deck; this one keeps going.
        --
        -- The ladder is depth over a square metre, because that is what
        -- a tile is: one litre is a millimetre of wet, and fifty is five
        -- centimetres -- over the boot line, which is where a puddle
        -- stops being something you walk through without noticing. The
        -- two upper tiers are tg's river tiles, which move.
        --
        -- `full_volume_ml = 1000` is where the wash reaches full alpha,
        -- so a litre already reads as a covered tile and everything
        -- above it is depth rather than opacity.
        {
            key = "flowing",
            phase = "liquid",
            full_volume_ml = 1000,
            alpha = { min = 0.15, max = 1.0 },
            tiers = {
                {
                    at_ml = 1,
                    sprites = {
                        "matter_liquid_1", "matter_liquid_2", "matter_liquid_3",
                        "matter_liquid_5", "matter_liquid_6",
                    },
                },
                { at_ml = 1000, sprites = { "matter_water" } },
                { at_ml = 50000, sprites = { "matter_deep_water" } },
            },
        },
        {
            key = "powder",
            phase = "solid",
            full_volume_ml = 50,
            alpha = { min = 0.25, max = 1.0 },
            tiers = { { at_ml = 1, sprites = { "matter_powder" } } },
        },
        {
            key = "granular",
            phase = "solid",
            full_volume_ml = 50,
            tiers = {
                { at_ml = 1, sprites = { "matter_granular_small" } },
                { at_ml = 25, sprites = { "matter_granular_large" } },
            },
        },
        {
            key = "amorphous",
            phase = "solid",
            full_volume_ml = 50,
            tiers = {
                { at_ml = 1, sprites = { "matter_amorphous_small" } },
                { at_ml = 25, sprites = { "matter_amorphous_large" } },
            },
        },
        {
            key = "crystalline",
            phase = "solid",
            full_volume_ml = 50,
            tiers = {
                {
                    at_ml = 1,
                    sprites = {
                        "matter_crystalline_1", "matter_crystalline_2",
                        "matter_crystalline_3", "matter_crystalline_4",
                    },
                },
                { at_ml = 25, sprites = { "matter_crystalline_large" } },
            },
        },
        {
            key = "chunks",
            phase = "solid",
            full_volume_ml = 50,
            tiers = { { at_ml = 1, sprites = { "matter_chunks" } } },
        },
    },
}
