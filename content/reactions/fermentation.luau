-- Wild fermentation: sugar in water slowly becomes ethanol and CO2,
-- happiest around room temperature — the BellCurve rate model
-- (FermiChem's shape) executing on the ONE reaction registry that also
-- runs plasma fires. A forgotten cola brews on the floor; a chilled or
-- boiled one won't. Stoichiometry is glucose's, scaled to be watchable.
return {
    id = "fermentation",
    reactants = { ["sugar:solid"] = 1.0, water = 0.2 },
    products = { ethanol = 2.0, ["co2:gas"] = 2.0 },
    bell = {
        temp_min = 285.0,
        opt_lo = 293.0,
        opt_hi = 303.0,
        temp_max = 315.0,
        exponent = 2.0,
        base_rate = 0.002,
    },
    energy = 2000.0,
}
