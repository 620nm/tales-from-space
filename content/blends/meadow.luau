-- A meadow: breathable air over a thin coat of grass. Paint it on natural
-- ground; the ground stays the tile's material and the grass is cell
-- matter that burns (reactions/grass_fire.luau).
--
-- 300 g of dry grass a square metre, a temperate grassland's standing
-- crop (a chosen figure). A blend is a density, so the grass row is that
-- over a tile's 3 m of height: a 1 m x 1 m x 3 m cell holds 1.85 mol, a
-- litre at grass's 0.3 g/mL (substances/plants/grass.luau).
local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local T = 293.15
local n = ONE_ATMOSPHERE_PA / (R * T)

local GRASS_G_PER_M2 = 300.0
local TILE_HEIGHT_M = 3.0
local MOLAR_MASS = 162.14

return {
    id = "meadow",
    name = "Meadow",
    rows = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
        { "grass:solid", GRASS_G_PER_M2 / MOLAR_MASS / TILE_HEIGHT_M },
    },
    temperature_k = T,
    amount = "per_m3",
}
