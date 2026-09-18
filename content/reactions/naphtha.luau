-- Collapsed CO2 hydrogenation; docs/PETROCHEMISTRY.md owns the model.
-- Pseudo-C8H16 balances atoms; rounded registry masses differ slightly.
-- The catalyst stays liquid and the window remains below fuel ashing.
return {
    id = "naphtha",
    reactants = { ["co2:gas"] = 8.0, ["hydrogen:gas"] = 24.0 },
    products = { ["naphtha:liquid"] = 1.0, ["water:liquid"] = 16.0 },
    catalysts = { ["synthesis_catalyst:liquid"] = 0.025 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 450.0,
            opt_lo = 455.0,
            opt_hi = 465.0,
            temp_max = 470.0,
            exponent = 2.0,
            base_rate = 0.00625,
        },
    },
}
