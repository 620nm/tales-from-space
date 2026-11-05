-- HCN fire: hydrogen cyanide burning in oxygen.
--
-- interactions we use:
--   4 HCN + 5 O2 -> 4 CO2 + 2 H2O + 2 N2 (hcn_fire)
--
-- Hydrogen cyanide burning in oxygen, written per mole of HCN:
-- HCN + 1.25 O2 -> CO2 + 0.5 H2O + 0.5 N2. Frost tracked indoors warms,
-- boils off as poison gas, and a spark burns that gas away.
--
-- Energy: the lower heating value from NIST WebBook formation enthalpies
-- (gas): HCN +135.14, CO2 -393.51, H2O -241.826 kJ/mol, so -649.6 kJ per
-- mole of HCN, written positive (exothermic, the engine's
-- docs/chemistry/reactions.md). The -671 kJ often quoted is the higher
-- heating value, with the water liquid.
--
-- Rate: tg's gas-fire shape and divisor (reactions/plasma_fire.luau). The
-- ramp runs from the flash point, -18 C = 255.15 K (CRC), to the
-- autoignition point, 538 C = 811.15 K (CRC).
local DH_F_HCN = 135.14e3
local DH_F_CO2 = -393.51e3
local DH_F_WATER_GAS = -241.826e3
local FLASH_K = 255.15
local AUTOIGNITION_K = 811.15

return {
    id = "hcn_fire",
    priority = "fire",
    requires = {
        { min = { "hcn:gas", 0.01 } },
        { min = { "o2:gas", 0.01 } },
        { column = { "alight", 0.5 } },
        { column_below = { "atmos_resin", 0.1 } },
    },
    temp_window = { lo = FLASH_K, hi = math.huge },
    reactants = { ["hcn:gas"] = 1.0, ["o2:gas"] = 1.25 },
    products = { ["co2:gas"] = 1.0, ["water:gas"] = 0.5, ["n2:gas"] = 0.5 },
    rate = {
        burn = {
            limiting = "hcn:gas",
            divisor = 9.0,
            ramp = { floor_k = FLASH_K, ceiling_k = AUTOIGNITION_K },
        },
    },
    energy = DH_F_HCN - DH_F_CO2 - 0.5 * DH_F_WATER_GAS,
}
