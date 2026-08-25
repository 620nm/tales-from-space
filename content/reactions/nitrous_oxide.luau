-- Nitrous oxide. tg: `/datum/chemical_reaction/nitrous_oxide`, 5 N2O
-- from 2 ammonia + 1 nitrogen + 2 oxygen, with the tightest temperature
-- window in the base game (recipes/others.dm:149-160):
--   required_temp = 525, optimal_temp = 550, overheat_temp = 575,
--   temp_exponent_factor = 0.2, thermic_constant = 35
--
-- THE DEPARTURE: the nitrogen leg goes and the atoms balance. With one
-- id per molecule the reaction that is actually available is
--   2 NH3 + 2 O2 -> N2O + 3 H2O
-- which is a real oxidation of ammonia and needs no separate nitrogen
-- press -- the nitrogen is already in the ammonia. tg's fifth product
-- goes with it: five moles of N2O out of two of ammonia was a fiction
-- balancing a fiction, and both halves of this one are real. The water
-- is a product now rather than nothing, which is the honest half of
-- the trade.
--
-- This is the reaction chamber's SHOWCASE. Fifty kelvin wide, and a
-- fifth-power ramp so the edges are nearly as good as the middle -- tg
-- comments its own thermic constant as "gives a bonus 15C wiggle room",
-- which is a recipe that fights you. Dial 550, watch it run; dial 500
-- or 650 and nothing happens at all.
--
-- IT NEEDS A LID AND AN ATMOSPHERE. Liquid ammonia only stands still
-- under its own vapour pressure, and the oxygen comes off a canister,
-- so this is a sealed bottle on a heater with a gas share over the
-- liquid. The gate is a hundred kilopascals of oxygen -- an
-- ATMOSPHERE rather than a quantity, which is what a partial-pressure
-- gate says and a mole count cannot.
--
-- Bell by the documented mapping, all four numbers tg's own:
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 575 + 25 = 600
-- and the exponent verbatim.
--
-- Energy by the documented rule, on TG'S product count rather than
-- this file's:
--   35 x 5 x 75.3 = 13177.5, rounded to 13178 J per extent
-- The rule is Q = THETA x r_product x 75.3 and the r that keeps the
-- FEEL is the one whose reactant side is unchanged: tg spends two
-- ammonia per extent and so does this, so the joules a chemist gets
-- per press of ammonia are tg's own. Rescaling to the surviving single
-- mole of N2O would have made the same batch a fifth as warm for no
-- reason a player could name.
--
-- The product is the atmos gas in the gas phase, the same n2o a
-- canister holds -- and unlike tg's, which spawns N2O on the turf only
-- when the batch comes out impure. Purity is deferred; the gas is not.
return {
    id = "nitrous_oxide",
    reactants = { ["ammonia:liquid"] = 2.0, ["o2:gas"] = 2.0 },
    products = { ["n2o:gas"] = 1.0, ["water:liquid"] = 3.0 },
    energy = 13178.0,
    requires = {
        { partial_pressure_at_least = { substance = "o2", kpa = 100.0 } },
    },
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
