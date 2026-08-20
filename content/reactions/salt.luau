-- Sodium chloride. tg: `/datum/chemical_reaction/sodiumchloride`,
-- 2 salt from 1 sodium + 1 chlorine, thermic_constant 50
-- (recipes/others.dm:44-48). The ratios are tg's units read as moles,
-- which is what the unit bridge buys (docs/reagents.md).
--
-- tg says nothing about temperature, so this gets the shared MIXING
-- BELL: 100/280/900/1000, which is tg's default window with the
-- plateau pulled down to room temperature so a beaker on the deck
-- actually does something. Every defaulted recipe on this shelf carries
-- the same four numbers.
--
-- Energy is the documented rule, Q = THETA x r_product x 75.3:
--   50 x 2 x 75.3 = 7530 J per extent
-- On a full 50 u beaker of 30 u water and 10 u each of the halves that
-- is about +23 K, against tg's +20 K -- the worked check in
-- docs/reagents.md.
return {
    id = "salt",
    reactants = { sodium = 1.0, chlorine = 1.0 },
    products = { salt = 2.0 },
    energy = 7530.0,
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
