-- HCN polymerization: liquid hydrogen cyanide setting to tholin.
--
-- interactions which require catalysts:
--   4 HCN(l) -> tholin, catalyst ammonia, blocked by sulfuric_acid (hcn_polymerization)
--
-- Liquid hydrogen cyanide polymerizing to tholin, the dark solid. A base
-- sets it off and an acid stops it, as in industry, where HCN is stored
-- with a little acid for exactly this reason. Nothing here is consumed
-- but the HCN.
--
-- Mass balance: tholin is the (HCN)4 unit, 108.10 g/mol
-- (substances/petrochemicals/tholin.luau), so one unit is four HCN.
--
-- Energy: -1600 kJ per kilogram polymerized (Gausse & Montgomery 1960,
-- cited by IChemE Hazards 25, Symposium Series 160, paper 52), so 173 kJ
-- per 108.10 g unit, written positive (exothermic, the engine's
-- docs/chemistry/reactions.md).
--
-- Window: liquid HCN, from its melting point 259.86 K; the 290-300 K
-- plateau holds its boiling point 299.0 K
-- (substances/petrochemicals/hcn.luau). The heat it makes climbs the
-- rising flank, which is the runaway; past 310 K, or once the liquid
-- boils away, it stops. Shared bell exponent and rescaled base rate
-- (the engine's docs/chemistry/rate-law.md).
local HCN_PER_THOLIN = 4.0
local THOLIN_MOLAR_MASS = 108.10
local HEAT_J_PER_KG = 1.6e6

return {
    id = "hcn_polymerization",
    reactants = { ["hcn:liquid"] = HCN_PER_THOLIN },
    products = { ["tholin:solid"] = 1.0 },
    catalysts = { ["ammonia:gas"] = 0.025 },
    requires = {
        { blocked = { "sulfuric_acid:liquid", 0.025 } },
    },
    energy = HEAT_J_PER_KG * THOLIN_MOLAR_MASS / 1000,
    rate = {
        bell = {
            temp_min = 259.86,
            opt_lo = 290.0,
            opt_hi = 300.0,
            temp_max = 310.0,
            exponent = 2.0,
            base_rate = 0.00625,
        },
    },
}
