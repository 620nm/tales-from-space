-- Methane pyrolysis: methane cracked to carbon and hydrogen over iron.
--
-- interactions which require catalysts:
--   CH4 -> C + 2 H2, catalyst iron (methane_pyrolysis)
--
-- Methane cracked over hot iron: the world's hydrogen source. The
-- hydrogen feeds ammonia and naphtha (reactions/ammonia.luau,
-- reactions/naphtha.luau) and the carbon is the shelf's carbon black.
-- The iron is a catalyst: present, never consumed.
--
-- Energy: endothermic by methane's formation enthalpy, -74.87 kJ/mol
-- (NIST WebBook), so -74 870 J per extent (the engine's
-- docs/chemistry/reactions.md).
--
-- Window: iron-catalysed methane decomposition runs 700-900 C
-- (973.15-1173.15 K, the plateau here). The bench heater tops out at
-- 1000 K (machines/chem_heater.luau), on the plateau. Shared bell
-- exponent and rescaled base rate (the engine's docs/chemistry/rate-law.md).
local DH_F_METHANE = -74.87e3

return {
    id = "methane_pyrolysis",
    reactants = { ["methane:gas"] = 1.0 },
    products = { ["carbon:solid"] = 1.0, ["hydrogen:gas"] = 2.0 },
    catalysts = { ["iron:solid"] = 0.025 },
    energy = DH_F_METHANE,
    rate = {
        bell = {
            temp_min = 900.0,
            opt_lo = 973.15,
            opt_hi = 1173.15,
            temp_max = 1250.0,
            exponent = 2.0,
            base_rate = 0.00625,
        },
    },
}
