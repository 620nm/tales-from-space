-- Saline-glucose solution. tg:
-- `/datum/chemical_reaction/medicine/salglu_solution`, 3 salglu from
-- 2 saltwater + 1 sugar (recipes/medicine.dm:92-95), inheriting
-- optimal_temp 700, temp_exponent_factor 1.2 and thermic_constant 50
-- from `/datum/chemical_reaction/medicine` (recipes/medicine.dm:2-11).
--
-- THE DEPARTURE: the saltwater leg is spelled out. tg carries brine as
-- its own reagent and makes it out of one water and one salt
-- (recipes/others.dm:909-912); one id per molecule deleted that
-- substance and that recipe, because a solution is not a compound and
-- there was nothing for a third id to name (D3, and the negative
-- assertion in tests/chem_bench_test.luau). So the two units of
-- saltwater tg asks for are written as what they were made of -- one
-- water and one salt -- and the product count stays at tg's three.
--
-- Everything else is tg's, and what it buys is the one healing chem on
-- this bench whose legs are all on the dispenser shelf: three buttons
-- and a beaker.
--
-- The window is the medicine base's numbers through the documented
-- mapping (docs/CHEMISTRY.md 5), with tg's own defaults supplying the
-- two the base does not state (recipes.dm:32-36):
--   temp_min = required_temp (default) = 100
--   opt_lo   = optimal_temp            = 700
--   opt_hi   = overheat_temp (default) = 900
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 900 + 600 = 1500
-- and the exponent verbatim: 1.2. This is NOT the shared mixing bell --
-- tg's medicine base states a temperature and the mixing bell is only
-- for a recipe that states none -- so a beaker on the deck runs it at
-- about a quarter speed and the chamber is worth walking to.
--
-- Energy by the documented rule, Q = THETA x r_product x 75.3:
--   50 x 3 x 75.3 = 11 295 J per extent
return {
    id = "salglu",
    reactants = { ["water:liquid"] = 1.0, ["salt:solid"] = 1.0, ["sugar:solid"] = 1.0 },
    products = { ["salglu:liquid"] = 3.0 },
    energy = 11295.0,
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
