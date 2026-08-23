-- Ammonia. tg: `/datum/chemical_reaction/ammonia`, 3 ammonia from
-- 3 hydrogen + 1 nitrogen, thermic_constant 50
-- (recipes/others.dm:432-439).
--
-- The nitrogen is the SAME gas the air is four fifths of, taken as a
-- liquid: a bare key on a
-- reaction side means liquid (docs/MATTER.md, section 6), and a
-- GasOnly substance carries its specific heat across all three phases
-- with no curve to transition on, so a liquid entry is legal and
-- inert. That is tg parity as well as convenience -- tg's nitrogen
-- REAGENT is a reagent, and the dispenser stocks it as one.
--
-- Shared mixing bell. Energy by the documented rule:
--   50 x 3 x 75.3 = 11295 J per extent
return {
    id = "ammonia",
    reactants = { hydrogen = 3.0, n2 = 1.0 },
    products = { ammonia = 3.0 },
    energy = 11295.0,
    rate = {
        bell = {
            temp_min = 100.0,
            opt_lo = 280.0,
            opt_hi = 900.0,
            temp_max = 1000.0,
            exponent = 2.0,
            base_rate = 0.05,
        },
    },
}
