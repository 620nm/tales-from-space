-- A frozen sheet in a bed. Laid where the map's surface is under freezing:
-- anywhere warmer the blend contradicts its profile and the map is refused.
local DENSITY_G_PER_ML = 0.917 -- substances/water.luau
local MOLAR_MASS = 18.015

return {
    id = "sheet_ice",
    name = "Sheet ice",
    name_label = "lunatic/tfs:blends.sheet_ice.name",
    rows = {
        { "water:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 259.15,
    amount = "per_m3",
    terrain = { profile = "sheet_ice" },
}
