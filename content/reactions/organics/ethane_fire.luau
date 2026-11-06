-- Ethane fire: ethane burning in oxygen.
--
-- interactions we use:
--   2 C2H6 + 7 O2 -> 4 CO2 + 6 H2O (ethane_fire)
--
-- Ethane burning in oxygen, written per mole of ethane:
-- C2H6 + 3.5 O2 -> 2 CO2 + 3 H2O. At 94 K ethane is a liquid with almost
-- no vapor over it, so a cold sea's ethane burns only once something
-- else (its methane, reactions/organics/methane_fire.luau) has warmed
-- the cell past ethane's flash point.
--
-- Energy: the lower heating value from NIST WebBook formation enthalpies
-- (gas): C2H6 -84.0, CO2 -393.51, H2O -241.826 kJ/mol, so -1428.5 kJ per
-- mole of ethane, written positive (exothermic, the engine's
-- docs/chemistry/reactions.md).
--
-- Rate: tg's gas-fire shape and divisor (reactions/plasma_fire.luau). The
-- ramp runs from the flash point, -135 C = 138.15 K (CRC), to the
-- autoignition point, 472 C = 745.15 K (CRC).
local DH_F_ETHANE = -84.0e3
local DH_F_CO2 = -393.51e3
local DH_F_WATER_GAS = -241.826e3
local FLASH_K = 138.15
local AUTOIGNITION_K = 745.15

return {
    id = "ethane_fire",
    priority = "fire",
    requires = {
        { min = { "ethane:gas", 0.01 } },
        { min = { "o2:gas", 0.01 } },
        { column = { "alight", 0.5 } },
        { column_below = { "atmos_resin", 0.1 } },
    },
    temp_window = { lo = FLASH_K, hi = math.huge },
    reactants = { ["ethane:gas"] = 1.0, ["o2:gas"] = 3.5 },
    products = { ["co2:gas"] = 2.0, ["water:gas"] = 3.0 },
    rate = {
        burn = {
            limiting = "ethane:gas",
            divisor = 9.0,
            ramp = { floor_k = FLASH_K, ceiling_k = AUTOIGNITION_K },
        },
    },
    energy = DH_F_ETHANE - 2 * DH_F_CO2 - 3 * DH_F_WATER_GAS,
}
