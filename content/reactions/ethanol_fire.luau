-- Ethanol vapour burning in air: C2H5OH + 3 O2 -> 2 CO2 + 3 H2O.
--
-- Only the gas burns; a puddle burns through its vapour, so the flame
-- follows the fuel as the pool boils off. The `alight` column is the
-- spark: the rule cannot fire without it, and once lit the fire holds
-- on fuel and heat from 250 K. The rate fades to nothing at 312 K, so a
-- fire settles under its ceiling rather than going out and relighting.
--
-- Atmos resin keeps new fires from starting, as it does for plasma
-- fire (reactions/plasma_fire.luau): its column must be under 0.1.
return {
    id = "ethanol_fire",
    priority = "fire",
    requires = {
        { min = { "ethanol:gas", 0.01 } },
        { min = { "o2:gas", 0.01 } },
        { column = { "alight", 0.5 } },
        { column_below = { "atmos_resin", 0.1 } },
    },
    temp_window = { lo = 250, hi = 312 },
    reactants = { ["ethanol:gas"] = 1.0, ["o2:gas"] = 3.0 },
    products = { ["co2:gas"] = 2.0, ["water:gas"] = 3.0 },
    rate = {
        bell = {
            temp_min = 250,
            opt_lo = 290,
            opt_hi = 306,
            temp_max = 312,
            exponent = 1.0,
            base_rate = 0.09,
        },
    },
    energy = 2.4e5,
}
