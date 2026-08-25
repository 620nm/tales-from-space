-- Epinephrine. tg: `/datum/chemical_reaction/medicine/epinephrine`,
-- 6 epinephrine from 1 phenol + 1 acetone + 1 diethylamine + 1 oxygen
-- + 1 chlorine + 1 hydrogen (recipes/medicine.dm:242-245), inheriting
-- optimal_temp 700, temp_exponent_factor 1.2 and thermic_constant 50
-- from `/datum/chemical_reaction/medicine` (recipes/medicine.dm:2-11).
--
-- THE DEPARTURE: the two gas legs are gone and the product count falls
-- from six to four. Oxygen and hydrogen are permanent gases here (D19,
-- docs/CHEMISTRY.md 7) and epinephrine is fictional as far as this
-- pack's arithmetic goes, so D1 lets the count fall with them -- four
-- legs in, four out. The chlorine leg stays and names its LIQUID, which
-- is the same stopper phenol needed, so the last step of the longest
-- chain on the bench is still bottle work.
--
-- It is the longest chain: phenol comes off water, liquid chlorine and
-- oil; acetone off oil and welding fuel; diethylamine off liquid
-- ammonia and ethanol. Three intermediates and two condensed gases, to
-- make the one medicine that does nothing at all until somebody is
-- already on the deck (substances/epinephrine.luau).
--
-- The window is the medicine base's numbers through the documented
-- mapping (docs/CHEMISTRY.md 5). tg's own defaults supply the two the
-- base does not state (recipes.dm:32-36):
--   temp_min = required_temp (default) = 100
--   opt_lo   = optimal_temp            = 700
--   opt_hi   = overheat_temp (default) = 900
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 900 + 600 = 1500
-- and the exponent verbatim: 1.2. At room temperature the bell is
-- ((300-100)/(700-100))^1.2 = 0.27, so a bottle on the deck works and
-- the chamber works four times faster.
--
-- Energy by the documented rule, Q = THETA x r_product x 75.3:
--   50 x 4 x 75.3 = 15 060 J per extent
return {
    id = "epinephrine",
    reactants = {
        ["phenol:liquid"] = 1.0,
        ["acetone:liquid"] = 1.0,
        ["diethylamine:liquid"] = 1.0,
        ["chlorine:liquid"] = 1.0,
    },
    products = { ["epinephrine:liquid"] = 4.0 },
    energy = 15060.0,
    rate = {
        bell = {
            temp_min = 100.0,
            opt_lo = 700.0,
            opt_hi = 900.0,
            temp_max = 1500.0,
            exponent = 1.2,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
