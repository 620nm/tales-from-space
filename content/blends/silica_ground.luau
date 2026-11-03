-- Bare quartz rock: what a tile's ground is made of when it is silica.
--
-- Ground is a recipe a tile NAMES (`material = Named("silica_ground")`), not
-- matter in the cell; the engine reads its substance, colour and resting
-- phase (docs/content-schema/terrain.md in the engine). `per_m3` because
-- it is a density, the solid's moles in one cubic metre: bulk density in
-- g/mL times 10^6 g per m3, over the molar mass in g/mol. A `total` blend
-- would be a dose, which no tile's ground is. 293.15 K is what an indoor
-- or temperate map holds.
local DENSITY_G_PER_ML = 2.65 -- substances/ground/silica.luau
local MOLAR_MASS = 60.08

return {
    id = "silica_ground",
    name = "Silica ground",
    name_label = "lunatic/tfs:blends.silica_ground.name",
    rows = {
        { "silica:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
}
