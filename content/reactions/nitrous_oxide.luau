-- Nitrous oxide. tg: `/datum/chemical_reaction/nitrous_oxide`, 5 N2O
-- from 2 ammonia + 1 nitrogen + 2 oxygen, with the tightest temperature
-- window in the base game (recipes/others.dm:149-160):
--   required_temp = 525, optimal_temp = 550, overheat_temp = 575,
--   temp_exponent_factor = 0.2, thermic_constant = 35
--
-- This is the reaction chamber's SHOWCASE. Fifty kelvin wide, and a
-- fifth-power ramp so the edges are nearly as good as the middle -- tg
-- comments its own thermic constant as "gives a bonus 15C wiggle room",
-- which is a recipe that fights you. Dial 550, watch it run; dial 500
-- or 650 and nothing happens at all.
--
-- Bell by the documented mapping, all four numbers tg's own:
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 575 + 25 = 600
-- and the exponent verbatim.
--
-- Energy by the documented rule:
--   35 x 5 x 75.3 = 13177.5, rounded to 13178 J per extent
--
-- The product is the builtin gas in the gas phase, the same as carbon
-- dioxide's -- and unlike tg's, which spawns N2O on the turf only when
-- the batch comes out impure. Purity is deferred; the gas is not.
return {
    id = "nitrous_oxide",
    reactants = { ammonia = 2.0, n2 = 1.0, o2 = 2.0 },
    products = { ["n2o:gas"] = 5.0 },
    energy = 13178.0,
    rate = {
        bell = {
            temp_min = 525.0,
            opt_lo = 550.0,
            opt_hi = 575.0,
            temp_max = 600.0,
            exponent = 0.2,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
