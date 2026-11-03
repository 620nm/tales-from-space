-- Standing fresh water: it evaporates, and what leaves it does not come back.
local DENSITY_G_PER_ML = 1.0 -- substances/water.luau
local MOLAR_MASS = 18.015

return {
    id = "lake_water",
    name = "Lake water",
    name_label = "lunatic/tfs:blends.lake_water.name",
    rows = {
        { "water", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
    terrain = { profile = "still_liquid" },
}
