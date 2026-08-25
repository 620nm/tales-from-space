-- Multiver. tg: `/datum/chemical_reaction/medicine/multiver`,
-- 2 multiver from 1 ash + 1 salt, required_temp 380, optimal_temp 400,
-- overheat_temp 410, temp_exponent_factor 0.1, thermic_constant 0
-- (recipes/cat2_medicines.dm:266-282).
--
-- No departure at all: both legs are real solids this pack already
-- makes, the ratio is tg's and so is the product count. It is the one
-- medicine on the bench that asks for nothing but a hotplate.
--
-- The window is tg's three numbers through the documented mapping
-- (docs/CHEMISTRY.md 5):
--   temp_min = required_temp = 380
--   opt_lo   = optimal_temp  = 400
--   opt_hi   = overheat_temp = 410
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 410 + 20 = 430
-- and the exponent verbatim: 0.1, which is a very flat curve. That is
-- tg's own claim about this recipe -- anywhere inside the band works
-- about as well as anywhere else -- and the interesting edge is the
-- floor, not the shape. Thirty kelvin is a NARROW band, and a chemist
-- who dials the chamber to its stop gets a hot beaker and nothing in
-- it: `BellCurve` is exactly zero above `temp_max` (docs/CHEMISTRY.md
-- 7).
--
-- tg gives it `thermic_constant = 0`, so the energy is zero -- the
-- documented default rather than a decision (docs/CHEMISTRY.md 6).
return {
    id = "multiver",
    reactants = { ["ash:solid"] = 1.0, ["salt:solid"] = 1.0 },
    products = { ["multiver:liquid"] = 2.0 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 380.0,
            opt_lo = 400.0,
            opt_hi = 410.0,
            temp_max = 430.0,
            exponent = 0.1,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
