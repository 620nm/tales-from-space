-- Warm-mix toner from four resin binder units, one carbon-black unit and
-- one wax flow aid. The composite product keeps the weighted input mass
-- and is already a solid powder when it leaves the beaker.
return {
    id = "toner",
    reactants = {
        ["polymer_resin:solid"] = 4.0,
        ["carbon:solid"] = 1.0,
        ["wax:solid"] = 1.0,
    },
    products = { ["toner:solid"] = 1.0 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 320.0,
            opt_lo = 325.0,
            opt_hi = 335.0,
            temp_max = 340.0,
            exponent = 2.0,
            -- A warm mixer reaches a printable batch in a few minutes,
            -- rather than inheriting the dilute bench rate.
            base_rate = 0.25,
        },
    },
}
