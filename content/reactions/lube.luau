-- Lube. tg: `/datum/chemical_reaction/lube`, 4 lube from 1 water +
-- 1 silicon + 1 oxygen, thermic_constant 50 (recipes/others.dm:8-12).
--
-- THE DEPARTURE: the oxygen leg is gone and the product count falls
-- from four to two. Oxygen is a permanent gas -- a source deposits
-- what a substance IS, and a gas over an open beaker leaves through
-- the same mouth (D19) -- so a bench recipe cannot stand on it. Lube
-- is a fictional product, so D1 lets the count move: two legs in, two
-- out, which keeps the thing a chemist feels (a press each, a full
-- beaker of lube) without pretending an atom balance nobody could
-- write.
--
-- Shared mixing bell. Energy by the documented rule:
--   50 x 2 x 75.3 = 7530 J per extent
return {
    id = "lube",
    reactants = { ["water:liquid"] = 1.0, ["silicon:solid"] = 1.0 },
    products = { ["lube:liquid"] = 2.0 },
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
