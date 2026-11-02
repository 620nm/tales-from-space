-- The same water, half a metre deep: sea_water's own shore.
local DENSITY_G_PER_ML = 1.0 -- substances/water.luau
local MOLAR_MASS = 18.015

return {
    id = "sea_shallows",
    name = "Sea shallows",
    rows = {
        { "water", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
    terrain = { depth_m = 0.5 },
}
