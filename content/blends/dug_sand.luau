-- Sand with a bed cut into it, dry: see sand_ground.luau for the density.
local DENSITY_G_PER_ML = 1.6 -- substances/ground/sand.luau
local MOLAR_MASS = 60.08

return {
    id = "dug_sand",
    name = "Dug sand",
    rows = {
        { "sand:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
    terrain = { profile = "dry_bed" },
}
