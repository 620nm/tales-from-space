-- Plant-cover blends: breathable air over a thin coat of dry plant matter,
-- returned whole by `blends/meadow.luau` and `blends/moss_carpet.luau`, and
-- read back by specs that declare the same blend on a test map.
--
-- A blend is a density, so a plant row is its grams a square metre over the
-- tile's height (lib/tile_geometry.luau) and cellulose's 162.14 g/mol
-- (substances/plants/{grass,moss}.luau).
local tile_geometry = require("@lib/tile_geometry")

local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local T = 293.15
local AIR_N = ONE_ATMOSPHERE_PA / (R * T)
local CELLULOSE_MOLAR_MASS = 162.14

export type PlantCover = {
    id: string,
    name: string,
    rows: { { string | number } },
    temperature_k: number,
    amount: string,
}

local function cover(id: string, name: string, plant: string, grams_per_m2: number): PlantCover
    return {
        id = id,
        name = name,
        rows = {
            { "o2", AIR_N * 0.21 },
            { "n2", AIR_N * 0.79 },
            { plant .. ":solid", grams_per_m2 / CELLULOSE_MOLAR_MASS / tile_geometry.height_m },
        },
        temperature_k = T,
        amount = "per_m3",
    }
end

return {
    -- 300 g of dry grass a square metre, a temperate grassland's standing
    -- crop (a chosen figure): about a litre a tile at grass's 0.3 g/mL.
    meadow = cover("meadow", "Meadow", "grass", 300.0),
    -- 200 g of dry moss a square metre (a chosen figure): about a litre a
    -- tile at moss's 0.2 g/mL.
    moss_carpet = cover("moss_carpet", "Moss carpet", "moss", 200.0),
}
