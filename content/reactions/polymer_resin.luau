-- Resin production: naphtha is polymerized into one equal-mass solid
-- bookkeeping unit. The catalyst stays liquid and is never consumed, so
-- the same beaker can synthesize naphtha and then finish resin without a
-- separator. Its lower window selects resin from the wax route.
return {
    id = "polymer_resin",
    reactants = { ["naphtha:liquid"] = 1.0 },
    products = { ["polymer_resin:solid"] = 1.0 },
    catalysts = { ["polymer_catalyst:liquid"] = 0.05 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 360.0,
            opt_lo = 365.0,
            opt_hi = 375.0,
            temp_max = 380.0,
            exponent = 2.0,
            base_rate = 0.00625,
        },
    },
}
