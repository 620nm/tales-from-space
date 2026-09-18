-- tg: code/modules/reagents/chemistry/recipes/others.dm:477-481.
-- Adapted balanced oxidation: C8H16 + 2 O2 -> 2 C3H6O + 2 C + 2 H2O.
-- Salt selects this cool route; docs/PETROCHEMISTRY.md owns the recipe.
return {
    id = "acetone",
    reactants = { ["naphtha:liquid"] = 1.0, ["o2:gas"] = 2.0 },
    products = {
        ["acetone:liquid"] = 2.0,
        ["carbon:solid"] = 2.0,
        ["water:liquid"] = 2.0,
    },
    catalysts = { ["salt:solid"] = 0.025 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 280.0,
            opt_lo = 285.0,
            opt_hi = 305.0,
            temp_max = 315.0,
            exponent = 2.0,
            base_rate = 0.00625,
        },
    },
}
