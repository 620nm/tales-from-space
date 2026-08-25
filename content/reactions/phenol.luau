-- Phenol. tg: `/datum/chemical_reaction/phenol`, 3 phenol from 1 water
-- + 1 chlorine + 1 oil, thermic_constant 50 (recipes/others.dm:584-588).
--
-- The ratio and the product count are tg's, unchanged. THE DEPARTURE is
-- one word: the chlorine leg names its LIQUID. There is one id per
-- molecule (D3), `chlorine` is Cl2, and Cl2 boils at 239 K -- so the
-- phase this recipe means exists in a sealed bottle under about eight
-- atmospheres of its own vapour and nowhere else. Press the chlorine
-- into a bottle, put the bottle on the deck until the condensation heat
-- is gone, then pour the oil in and press the water: that is the first
-- rung of the medicine trunk, and the stopper is not optional.
--
-- tg states no temperature, so this gets the shared MIXING BELL:
-- 100/280/900/1000, tg's default window with the plateau pulled down to
-- room temperature (docs/CHEMISTRY.md 5). Every defaulted recipe on
-- this shelf carries the same four numbers.
--
-- Energy is the documented rule, Q = THETA x r_product x 75.3:
--   50 x 3 x 75.3 = 11 295 J per extent
-- which is enough to boil a share of the bottle's own chlorine back off
-- as it works -- so the run tails off against a saturated headspace
-- rather than stopping dead, the same lesson salt teaches
-- (tests/chem_bench_test.luau).
return {
    id = "phenol",
    reactants = { ["water:liquid"] = 1.0, ["chlorine:liquid"] = 1.0, ["oil:liquid"] = 1.0 },
    products = { ["phenol:liquid"] = 3.0 },
    energy = 11295.0,
    rate = {
        bell = {
            temp_min = 100.0,
            opt_lo = 280.0,
            opt_hi = 900.0,
            temp_max = 1000.0,
            exponent = 2.0,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
