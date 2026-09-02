-- The air a room opens with when nobody has painted it: 21% oxygen,
-- 79% nitrogen, at 20 C.
--
-- `default = true` is what makes that sentence true. The engine ships
-- no air of its own — before this marker it deposited a hardcoded 21/79
-- into every unpainted floor tile, which was one more recipe under
-- `crates/` that a mod could not change (docs/ATMOS.md §11). Now the
-- pack says which of its blends an unpainted tile opens with, and a
-- pack that says nothing opens its rooms empty.
--
-- This file also exists so a mapper can PAINT that same air back onto a
-- room they emptied by accident, and so the editor has something to
-- copy when it offers the defaults.
--
-- The numbers are not typed out; they are the arithmetic spelled again.
-- One tile is 1 m3 and pV/RT at one atmosphere and 293.15 K is what a
-- room full of ordinary air holds (docs/MATTER.md 3).
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
    default = true,
    rows = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
    },
    temperature_k = T,
    amount = "per_tile",
}
