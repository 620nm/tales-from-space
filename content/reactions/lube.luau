-- Lube. tg: `/datum/chemical_reaction/lube`, 4 lube from 1 water +
-- 1 silicon + 1 oxygen, thermic_constant 50 (recipes/others.dm:7-11).
--
-- The oxygen is the builtin gas as a liquid, the same way ammonia's
-- nitrogen is -- see that file.
--
-- Shared mixing bell. Energy by the documented rule:
--   50 x 4 x 75.3 = 15060 J per extent
-- Four moles out of three in, so this is the warmest thing the bench
-- makes at room temperature.
return {
    id = "lube",
    reactants = { water = 1.0, silicon = 1.0, o2 = 1.0 },
    products = { lube = 4.0 },
    energy = 15060.0,
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
