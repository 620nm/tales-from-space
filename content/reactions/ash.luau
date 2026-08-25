-- Ash. tg: `/datum/chemical_reaction/ash`, 1 ash from 1 oil,
-- `required_temp = 480`, no thermic_constant (recipes/others.dm:589-593).
--
-- The first recipe on this shelf that a cold beaker cannot run, and
-- therefore the first one that needs the reaction chamber. The bell is
-- the documented MAPPING of tg's three temperatures rather than the
-- shared mixing bell (docs/CHEMISTRY.md):
--   temp_min = required_temp            = 480
--   opt_lo   = optimal_temp   (default) = 500   (recipes.dm:34)
--   opt_hi   = overheat_temp  (default) = 900   (recipes.dm:36)
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 920
-- exponent is tg's `temp_exponent_factor` default of 2 (recipes.dm:44).
return {
    id = "ash",
    reactants = { oil = 1.0 },
    products = { ash = 1.0 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 480.0,
            opt_lo = 500.0,
            opt_hi = 900.0,
            temp_max = 920.0,
            exponent = 2.0,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
