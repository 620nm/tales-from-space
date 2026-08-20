-- Saltpetre. tg: `/datum/chemical_reaction/saltpetre`, 3 saltpetre from
-- 1 potassium + 1 nitrogen + 3 oxygen, no thermic_constant
-- (recipes/others.dm:775-778).
--
-- Five parts in for three out, three of them oxygen: the recipe that
-- empties a beaker fastest, and the one that makes the two gas buttons
-- on the dispenser earn their place.
--
-- Shared mixing bell, no energy.
return {
    id = "saltpetre",
    reactants = { potassium = 1.0, n2 = 1.0, o2 = 3.0 },
    products = { saltpetre = 3.0 },
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
