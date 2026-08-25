-- Salt dissolving. tg: `/datum/chemical_reaction/saltwater`, 2 salt
-- water from 1 water + 1 salt, no thermic_constant
-- (recipes/others.dm:909-912).
--
-- The shared mixing bell (100/280/900/1000) and no energy at all, which
-- is tg's own default: dissolving salt in water is not something
-- anybody feels.
return {
    id = "saltwater",
    reactants = { water = 1.0, ["salt:solid"] = 1.0 },
    products = { saltwater = 2.0 },
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
