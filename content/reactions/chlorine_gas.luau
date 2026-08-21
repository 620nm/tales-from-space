-- Two atoms make a molecule: warm the bench's `chlorine` past 420 K
-- and it pairs off into `cl2`, as GAS.
--
-- The twin of reactions/ammonia_gas.luau, and the same policy (D3,
-- docs/reagents.md). tg's chlorine reagent is a single atom because its
-- salt recipe is 1:1 with sodium; the real thing is diatomic and boils
-- at 239.1 K. Two of the reagent for one of the molecule, which is the
-- stoichiometry the names already imply.
--
-- WHERE THE WINDOW GOES.
--
-- The rule is ammonia_gas.luau's: a gate sits above every temperature
-- its own reactant is worked at by something already shipped. Chlorine
-- has exactly one other consumer, salt, and salt is made at room
-- temperature -- but it is EXOTHERMIC, and a brim-full beaker of the
-- halves heats itself +82 K on its own (tests/chem_bench_test.luau),
-- landing at 382 K. A gate below that would mean a third of every
-- batch of salt boiling off as chlorine gas, which is precisely the
-- shipped-recipe damage policy D3 exists to prevent.
--
-- 420/435/500/520, then: nearly forty kelvin of clearance over salt
-- making itself hot, and shut again before nitrous oxide's 525 K window
-- opens, so a vessel on its way to laughing gas never makes this by
-- accident. Much lower than ammonia's gate, and deliberately -- this is
-- the one the game wants a chemist to be able to reach, and the one
-- that hurts when they do.
--
-- `energy = 0` for ammonia_gas.luau's reason: the heat of vaporization
-- lives on the cl2 phase curve, and charging it twice would be paying
-- for the same physics on both sides of one door.
--
-- `volatile`: the first trip in any vessel is a row. Chlorine gas is
-- the most dangerous thing this shelf can make by accident, and a
-- record of when it started is the difference between a shift
-- investigation and a guess.
return {
    id = "chlorine_gas",
    reactants = { chlorine = 2.0 },
    products = { ["cl2:gas"] = 1.0 },
    energy = 0.0,
    volatile = true,
    rate = {
        bell = {
            temp_min = 420.0,
            opt_lo = 435.0,
            opt_hi = 500.0,
            temp_max = 520.0,
            exponent = 2.0,
            base_rate = 0.05,
        },
    },
}
