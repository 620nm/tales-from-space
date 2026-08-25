-- Lye, the long way. tg has two: `lye` (from sodium, hydrogen and
-- oxygen, recipes/others.dm:781-785) and `lye2` (from ash, water and
-- carbon, recipes/others.dm:786-789). This pack ports the SECOND,
-- because it is the one that consumes something the bench had to make
-- -- the third link in oil -> ash -> lye, and the only recipe on the
-- shelf that a dispenser alone cannot reach.
--
-- 2 lye from 1 ash + 1 water + 1 carbon, no thermic_constant. Shared
-- mixing bell: once the ash exists, this runs cold.
return {
    id = "lye",
    reactants = { ash = 1.0, water = 1.0, carbon = 1.0 },
    products = { lye = 2.0 },
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
