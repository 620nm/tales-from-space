-- interactions which require catalysts: n HCN -> tholin, catalyst ammonia, blocked by sulfuric_acid (hcn_polymerisation)
-- interactions we know exist but don't need: HCN polymerisation releasing ammonia and CO: tholin is the one product the world needs
--
-- Liquid hydrogen cyanide polymerising to tholin, the dark solid. A base
-- sets it off and an acid stops it, as in industry, where HCN is stored
-- with a little acid for exactly this reason. Nothing here is consumed
-- but the HCN.
--
-- Mass balance: tholin is a 100 g/mol bookkeeping unit (the `tholin`
-- substance file), so one unit is 100 / 27.025 moles of HCN
-- (27.025 g/mol, NIST WebBook).
--
-- Energy: -1600 kJ per kilogram polymerised (Gausse & Montgomery 1960,
-- cited by IChemE Hazards 25, Symposium Series 160, paper 52), so 160 kJ
-- per 100 g unit, written positive (exothermic, the engine's
-- docs/chemistry/reactions.md).
--
-- Window: liquid HCN, from its melting point 259.9 K; the 290-300 K
-- plateau holds its boiling point 298.8 K (NIST WebBook). The heat it
-- makes climbs the rising flank, which is the runaway; past 310 K, or
-- once the liquid boils away, it stops. Shared bell exponent and
-- rescaled base rate (the engine's docs/chemistry/rate-law.md).
local HCN_MOLAR_MASS = 27.025
local THOLIN_MOLAR_MASS = 100.0
local HEAT_J_PER_KG = 1.6e6

return {
    id = "hcn_polymerisation",
    reactants = { ["hcn:liquid"] = THOLIN_MOLAR_MASS / HCN_MOLAR_MASS },
    products = { ["tholin:solid"] = 1.0 },
    catalysts = { ["ammonia:gas"] = 0.025 },
    requires = {
        { blocked = { "sulfuric_acid:liquid", 0.025 } },
    },
    energy = HEAT_J_PER_KG * THOLIN_MOLAR_MASS / 1000,
    rate = {
        bell = {
            temp_min = 259.9,
            opt_lo = 290.0,
            opt_hi = 300.0,
            temp_max = 310.0,
            exponent = 2.0,
            base_rate = 0.00625,
        },
    },
}
