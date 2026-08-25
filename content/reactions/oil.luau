-- Oil. tg: `/datum/chemical_reaction/oil`, 3 oil from 1 welding fuel +
-- 1 carbon + 1 hydrogen, no thermic_constant
-- (recipes/others.dm:578-581).
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
    reactants = { welding_fuel = 1.0, ["carbon:solid"] = 1.0, hydrogen = 1.0 },
    products = { oil = 3.0 },
    energy = 0.0,
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
