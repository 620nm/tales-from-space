-- Wax production is the alternate naphtha finishing route. Sulphuric
-- acid selects it, while polymer catalyst suppresses it if both process
-- aids are in the beaker. That gate makes the recipe choice legible and
-- prevents both products racing over the same feedstock.
return {
    id = "wax",
    reactants = { ["naphtha:liquid"] = 1.0 },
    products = { ["wax:solid"] = 1.0 },
    catalysts = { ["sulfuric_acid:liquid"] = 0.05 },
    requires = { { blocked = { "polymer_catalyst:liquid", 0.05 } } },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 370.0,
            opt_lo = 375.0,
            opt_hi = 395.0,
            temp_max = 400.0,
            exponent = 2.0,
            base_rate = 0.00625,
        },
    },
}
