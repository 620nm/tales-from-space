-- Oil. tg: `/datum/chemical_reaction/oil`, 3 oil from 1 welding fuel +
-- 1 carbon + 1 hydrogen (recipes/others.dm:579-582), no
-- thermic_constant.
--
-- THE DEPARTURE: the hydrogen leg is gone and the product count falls
-- from three to two. tg's hydrogen reagent is a single atom you can
-- keep in a beaker; there is one id per molecule here, so hydrogen is
-- H2, a permanent gas, and no source hands one to an open glass (D19).
-- Oil is fiction, so D1 lets the count move with the legs: two in, two
-- out.
--
-- The welding fuel is the same substance a torch burns
-- (substances/welding_fuel.luau): one roster, so the thing in the
-- welder's tank and the thing on the dispenser's shelf are the same
-- thing, and a chemist can make more of what an engineer spends.
--
-- Shared mixing bell, no energy. This is step one of the chain the
-- reaction chamber exists for: oil to ash to lye.
return {
    id = "oil",
    reactants = { ["welding_fuel:liquid"] = 1.0, ["carbon:solid"] = 1.0 },
    products = { ["oil:liquid"] = 2.0 },
    energy = 0.0,
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
