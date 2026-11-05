-- interactions we use: CH4(l) + 2 O2(l) -> CO2 + 2 H2O (lox_detonation)
-- interactions we know exist but don't need: liquid oxygen with every other organic (ethane, lube, naphtha, wax, blood): one cryogenic pair is the hazard this world needs (K16)
-- interactions we know exist but don't need: liquid oxygen with solid methane below 90.69 K: no cell here is that cold
--
-- Liquid oxygen soaked into liquid methane: a spark and the whole pool
-- goes at once. The burn takes the limiting liquid in one pass (divisor
-- 1), and the onset is a blast (content/main.luau sends this rule's
-- `matter.ignition.done` to `lib/blast.luau`). It needs no air: the latch
-- lights it against the liquid oxygen (lib/ignition.luau `LOX_FUELS`).
--
-- Energy: methane's lower heating value, 802.3 kJ/mol
-- (reactions/organics/methane_fire.luau), less the vaporisation of the
-- liquids it starts from: methane 8.19 kJ/mol and oxygen 6.82 kJ/mol
-- (NIST WebBook), so 780.5 kJ per mole of methane.
--
-- Ramp: zero at oxygen's triple point, 54.36 K, the coldest liquid
-- oxygen there is, and full at methane's, 90.69 K (NIST WebBook), where
-- the fuel first melts. Any liquid pair is above it, so a latch fires the
-- whole extent at once.
local METHANE_LHV = 802.292e3
local METHANE_L_VAP = 8.19e3
local O2_L_VAP = 6.82e3
local O2_TRIPLE_K = 54.36
local METHANE_TRIPLE_K = 90.69

return {
    id = "lox_detonation",
    priority = "fire",
    requires = {
        { min = { "methane:liquid", 0.01 } },
        { min = { "o2:liquid", 0.01 } },
        { column = { "alight", 0.5 } },
        { column_below = { "atmos_resin", 0.1 } },
    },
    temp_window = { lo = O2_TRIPLE_K, hi = math.huge },
    reactants = { ["methane:liquid"] = 1.0, ["o2:liquid"] = 2.0 },
    products = { ["co2:gas"] = 1.0, ["water:gas"] = 2.0 },
    rate = {
        burn = {
            limiting = "methane:liquid",
            divisor = 1.0,
            ramp = { floor_k = O2_TRIPLE_K, ceiling_k = METHANE_TRIPLE_K },
        },
    },
    energy = METHANE_LHV - METHANE_L_VAP - 2 * O2_L_VAP,
    volatile = true,
}
