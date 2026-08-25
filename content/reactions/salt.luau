-- Sodium chloride. tg: `/datum/chemical_reaction/sodiumchloride`,
-- 2 salt from 1 sodium + 1 chlorine, thermic_constant 50
-- (recipes/others.dm:46-50).
--
-- THE DEPARTURE: two sodium, not one. tg's chlorine reagent is a
-- single ATOM, which is why its recipe balances 1:1; there is one id
-- per molecule here and `chlorine` is Cl2, so the ratio the molecule
-- actually says is 2 Na + Cl2 -> 2 NaCl. The product count is tg's own
-- 2 and the sodium doubles to match it. Everything else -- the window,
-- the thermic constant, the product -- is tg's.
--
-- AND THE OTHER DEPARTURE: it needs a lid. Chlorine is a gas at room
-- temperature, so `chlorine:liquid` exists only where something holds
-- it under its own vapour pressure -- a sealed bottle, about 8 atm at
-- 300 K. Salt is the bench's introduction to that: press the sodium,
-- press the chlorine, and the reason the vessel has a stopper in it is
-- the whole first lesson.
--
-- tg says nothing about temperature, so this gets the shared MIXING
-- BELL: 100/280/900/1000, which is tg's default window with the
-- plateau pulled down to room temperature so a beaker on the deck
-- actually does something. Every defaulted recipe on this shelf carries
-- the same four numbers.
--
-- Energy is the documented rule, Q = THETA x r_product x 75.3:
--   50 x 2 x 75.3 = 7530 J per extent
-- On a full 50 u vessel that is about +23 K against tg's +20 K -- the
-- worked check in docs/CHEMISTRY.md.
return {
    id = "salt",
    reactants = { ["sodium:solid"] = 2.0, ["chlorine:liquid"] = 1.0 },
    products = { ["salt:solid"] = 2.0 },
    energy = 7530.0,
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
