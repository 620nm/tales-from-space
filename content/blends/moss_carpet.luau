-- A moss carpet: breathable air over a thin mat of moss. Paint it on
-- natural ground, as meadow.luau paints grass; it burns by
-- reactions/moss_fire.luau.
--
-- 200 g of dry moss a square metre (a chosen figure), over a tile's 3 m
-- of height: a 1 m x 1 m x 3 m cell holds 1.23 mol, a litre at moss's
-- 0.2 g/mL (substances/plants/moss.luau).
local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local T = 293.15
local n = ONE_ATMOSPHERE_PA / (R * T)

local MOSS_G_PER_M2 = 200.0
local TILE_HEIGHT_M = 3.0
local MOLAR_MASS = 162.14

return {
    id = "moss_carpet",
    name = "Moss carpet",
    rows = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
        { "moss:solid", MOSS_G_PER_M2 / MOLAR_MASS / TILE_HEIGHT_M },
    },
    temperature_k = T,
    amount = "per_m3",
}
