-- interactions we use: CH4 + 2 O2 -> CO2 + 2 H2O (methane_fire)
-- interactions we know exist but don't need: methane outside its flammability limits (5-15 % in air): the latch and the burn rate stand in for a mixture gate
--
-- Methane burning in oxygen. In a cold methane sky the fire is inverted:
-- the air is fuel and the oxygen is what leaks out of a habitat, so the
-- flame lives in the plume. The products are hot gas that freezes back
-- out as dry ice and water ice once the cell cools to the sky.
--
-- Energy: the lower heating value from NIST WebBook formation enthalpies
-- (gas): CH4 -74.87, CO2 -393.51, H2O -241.826 kJ/mol, so -802.3 kJ per
-- mole of methane, written positive (exothermic, the engine's
-- docs/chemistry/reactions.md). Water is a product gas, so its latent
-- heat is the phase step's when it freezes out.
--
-- Rate: tg's gas-fire shape (reactions/plasma_fire.luau), its divisor 9.
-- The ramp runs from methane's flash point, -188 C = 85.15 K (CRC), so a
-- spark lights a plume at 94 K, to its autoignition point, 537 C =
-- 810.15 K (CRC), where the burn is at full speed.
local DH_F_METHANE = -74.87e3
local DH_F_CO2 = -393.51e3
local DH_F_WATER_GAS = -241.826e3
local FLASH_K = 85.15
local AUTOIGNITION_K = 810.15

return {
    id = "methane_fire",
    priority = "fire",
    requires = {
        { min = { "methane:gas", 0.01 } },
        { min = { "o2:gas", 0.01 } },
        { column = { "alight", 0.5 } },
        { column_below = { "atmos_resin", 0.1 } },
    },
    temp_window = { lo = FLASH_K, hi = math.huge },
    reactants = { ["methane:gas"] = 1.0, ["o2:gas"] = 2.0 },
    products = { ["co2:gas"] = 1.0, ["water:gas"] = 2.0 },
    rate = {
        burn = {
            limiting = "methane:gas",
            divisor = 9.0,
            ramp = { floor_k = FLASH_K, ceiling_k = AUTOIGNITION_K },
        },
    },
    energy = DH_F_METHANE - DH_F_CO2 - 2 * DH_F_WATER_GAS,
}
