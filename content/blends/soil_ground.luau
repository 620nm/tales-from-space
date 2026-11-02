-- Bare dry soil. A tile NAMES it as its ground
-- (`material = Named("soil_ground")`); see silica_ground.luau for why a
-- ground is a `per_m3` density of solid and not a dose.
--
-- Moles in one cubic metre: bulk 1.3 g/mL * 10^6 g per m3 over 60 g/mol
-- (substances/ground/soil.luau).
local DENSITY_G_PER_ML = 1.3
local MOLAR_MASS = 60.0

return {
    id = "soil_ground",
    name = "Soil ground",
    rows = {
        { "soil:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
}
