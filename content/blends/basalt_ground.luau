-- Bare basalt: dark volcanic rock. A tile NAMES it as its ground
-- (`material = Named("basalt_ground")`); see silica_ground.luau for why a
-- ground is a `per_m3` density of solid and not a dose.
--
-- Moles in one cubic metre: 2.9 g/mL * 10^6 g per m3 over 62.4 g/mol
-- (substances/basalt.luau).
local DENSITY_G_PER_ML = 2.9
local MOLAR_MASS = 62.4

return {
    id = "basalt_ground",
    name = "Basalt ground",
    rows = {
        { "basalt:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 293.15,
    amount = "per_m3",
}
