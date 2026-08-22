-- The air a room opens with when nobody has painted it: 21% oxygen,
-- 79% nitrogen, at 20 C. This file exists so a mapper can PAINT that
-- same air back onto a room they emptied by accident, and so the
-- editor has something to copy when it offers the defaults.
--
-- The numbers are not typed out; they are the engine's own arithmetic
-- spelled again. One tile is 1 m3 and pV/RT at one atmosphere and
-- 293.15 K is what MatterWorld::standard_air_cell deposits (its
-- lunatic_matter::standard_moles, docs/MATTER.md 3) -- so a room
-- painted with this is byte-for-byte a room nobody painted.
--
-- tg's own default open turf is the same mixture:
-- OPENTURF_DEFAULT_ATMOS = "o2=22;n2=82;TEMP=293.15"
-- (code/__DEFINES/atmospherics/atmos_mapping_helpers.dm:7), which is
-- 21.15/78.85 over its 2.5 m3 cell.
local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local TILE_VOLUME_M3 = 1.0
local T = 293.15
local n = ONE_ATMOSPHERE_PA * TILE_VOLUME_M3 / (R * T)

return {
    id = "standard_air",
    name = "Standard air",
    gases = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
    },
    temperature_k = T,
}
