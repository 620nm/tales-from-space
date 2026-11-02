-- Loose dry sand. A tile NAMES it as its ground
-- (`material = Named("sand_ground")`); see silica_ground.luau for why a
-- ground is a `per_m3` density of solid and not a dose.
--
-- Moles in one cubic metre: the BULK 1.6 g/mL * 10^6 g per m3 over 60.08
-- g/mol (substances/sand.luau); the voids between grains are why it is
-- fewer than silica's.
local DENSITY_G_PER_ML = 1.6
local MOLAR_MASS = 60.08

return {
    id = "sand_ground",
    name = "Sand ground",
    rows = {
        { "sand:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
}
