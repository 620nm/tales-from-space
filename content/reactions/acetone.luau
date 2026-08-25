-- Acetone. tg: `/datum/chemical_reaction/acetone`, 3 acetone from
-- 1 oil + 1 welding fuel + 1 oxygen, thermic_constant 50
-- (recipes/others.dm:477-481).
--
-- THE DEPARTURE: the oxygen leg is gone and the product count falls
-- from three to two. Oxygen is a permanent gas -- a source deposits
-- what a substance IS, and a gas over an open beaker leaves through the
-- same mouth (D19, docs/CHEMISTRY.md 7) -- so a bench recipe cannot
-- stand on it. Acetone is a fictional product as far as this pack is
-- concerned, so D1 lets the count move: two legs in, two out, which is
-- exactly what lube and oil did with the same problem.
--
-- Shared mixing bell (docs/CHEMISTRY.md 5): tg states no temperature,
-- so this runs in an open beaker on the deck. Energy by the documented
-- rule:
--   50 x 2 x 75.3 = 7530 J per extent
--
-- It SHRINKS: a mole of oil is 189 mL and a mole of fuel is 26, against
-- 148 for the two acetone that come out, so the free shell volume never
-- caps this one (D16). It is the only step in the epinephrine chain
-- that does not need a bottle.
return {
    id = "acetone",
    reactants = { ["oil:liquid"] = 1.0, ["welding_fuel:liquid"] = 1.0 },
    products = { ["acetone:liquid"] = 2.0 },
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
