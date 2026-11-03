-- A basalt cliff: basalt_ground's rock, laid as the `cliff` terrain
-- profile (terrain.luau), so the tile blocks a body and draws the stepped
-- face in basalt's own colour.
local DENSITY_G_PER_ML = 2.9 -- substances/ground/basalt.luau
local MOLAR_MASS = 62.4

return {
    id = "basalt_cliff",
    name = "Basalt cliff",
    name_label = "lunatic/tfs:blends.basalt_cliff.name",
    rows = {
        { "basalt:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
    terrain = { profile = "cliff" },
}
