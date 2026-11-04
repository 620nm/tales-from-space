-- The same water, half a metre deep: sea_water's own shore, laid by the
-- `shallows` terrain profile (terrain.luau).
local DENSITY_G_PER_ML = 1.0 -- substances/water.luau
local MOLAR_MASS = 18.015

return {
    id = "sea_shallows",
    name = "Sea shallows",
    name_label = "lunatic/tfs:blends.sea_shallows.name",
    rows = {
        { "water", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
    terrain = { profile = "shallows" },
}
