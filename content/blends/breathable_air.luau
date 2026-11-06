-- The breathable room air: 21% oxygen, 79% nitrogen, at 20 C and one
-- atmosphere. What a room opens with when nobody has painted it.
--
-- `default = true` is what makes that sentence true. The engine ships
-- no air of its own: the pack says which of its blends an unpainted
-- tile opens with, and a pack that says nothing opens its rooms empty
-- (the engine's `docs/atmos/blends.md`).
--
-- Named for what it is: the air every room is commissioned full of,
-- at the mixture its crew breathes. (Previously `standard_air`.)
--
-- This file also exists so a mapper can PAINT that same air back onto a
-- room they emptied by accident, and so the editor has something to
-- copy when it offers the defaults.
--
-- The numbers are not typed out; they are the arithmetic spelled again.
-- `amount = "per_m3"` makes this a density: moles per cubic meter, which
-- is p/RT at one atmosphere and 293.15 K. A cell gets that times its own
-- volume, so a 3 m3 room holds three times what a 1 m3 one does.
--
-- tg's own default open turf is the same mixture:
-- OPENTURF_DEFAULT_ATMOS = "o2=22;n2=82;TEMP=293.15"
-- (code/__DEFINES/atmospherics/atmos_mapping_helpers.dm:7), which is
-- 21.15/78.85 over its 2.5 m3 cell.
local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local T = 293.15
local n = ONE_ATMOSPHERE_PA / (R * T)

return {
    id = "breathable_air",
    name = "Breathable air",
    default = true,
    rows = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
    },
    temperature_k = T,
    amount = "per_m3",
}
