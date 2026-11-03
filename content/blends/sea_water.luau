-- Open sea: what a tile standing in a sea is filled with. `per_m3` for the
-- same reason as silica_ground.luau; the profile is the default liquid's.
local DENSITY_G_PER_ML = 1.0 -- substances/water.luau
local MOLAR_MASS = 18.015

return {
    id = "sea_water",
    name = "Sea water",
    rows = {
        { "water", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
}
