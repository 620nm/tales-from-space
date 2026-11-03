-- A quartz cliff: silica_ground's rock, laid as the `cliff` terrain
-- profile (terrain.luau), so the tile blocks a body and draws the stepped
-- face in silica's own colour.
local DENSITY_G_PER_ML = 2.65 -- substances/ground/silica.luau
local MOLAR_MASS = 60.08

return {
    id = "silica_cliff",
    name = "Silica cliff",
    name_label = "lunatic/tfs:blends.silica_cliff.name",
    rows = {
        { "silica:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
    terrain = { profile = "cliff" },
}
