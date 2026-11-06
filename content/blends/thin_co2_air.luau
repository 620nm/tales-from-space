-- Carbon dioxide at about 610 Pa and 210 K: the sky `mars_surface` opens
-- on. Real figures, not tg's: 610 Pa is Mars's reference-level pressure
-- (610.5 Pa, the datum its elevations are measured from; the mean surface
-- reads 636 Pa) and 210 K its mean surface temperature (NASA Mars fact sheet).
--
-- The row says `:gas` out loud. At one atmosphere CO2 sublimes at 194.7 K
-- (substances/co2.luau), so an unsuffixed row at 210 K would rest as dry
-- ice; at 610 Pa it is a gas well clear of the sublimation line, which
-- the engine's one-atmosphere rest rule cannot know.
--
-- `per_m3`: moles per cubic meter, p/RT, so a tile's cell holds it times
-- its volume and reads 610 Pa.
local R = 8.314
local PRESSURE_PA = 610.0
local T = 210.0

return {
    id = "thin_co2_air",
    name = "Thin carbon dioxide air",
    rows = {
        { "co2:gas", PRESSURE_PA / (R * T) },
    },
    temperature_k = T,
    amount = "per_m3",
}
