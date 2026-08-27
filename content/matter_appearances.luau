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
