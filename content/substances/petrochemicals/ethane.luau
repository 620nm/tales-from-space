-- Ethane: C2H6, the heavy half of a cold world's seas.
--
-- interactions we use:
--   2 C2H6 + 7 O2 -> 4 CO2 + 6 H2O (ethane_fire)
-- interactions which require catalysts:
--   4 C2H6 -> C8H16 + 4 H2, catalyst synthesis_catalyst (ethane_to_naphtha)
-- interactions we know exist but don't need:
--   freezing-point depression and the CH4/C2H6 eutectic: each substance
--     freezes at its own melting line, mixed or not, and a 94 K sea is
--     above both lines anyway
--   C2H6 -> C2H4, C2H2 and C6H6 by sunlight: the photochemistry that
--     makes a real cold world's fallout; the pack has none of those
--     substances, and its fallout is authored HCN snow instead
--
-- Numbers are the NIST WebBook's for ethane (C74840): triple point
-- 90.37 K at 1.14 Pa, normal boiling point 184.6 K, critical
-- temperature 305.3 K, heat of vaporization 14.69 kJ/mol at the boiling
-- point, heat of fusion 2.859 kJ/mol. Liquid density 0.65 g/mL near the
-- triple point (a sea's temperature, not the boiling point's 0.54); the
-- solid's 0.72 is approximate (CRC). Gas cv 44.2 is the 298 K cp of 52.5
-- less R; the condensed cv figures are approximate cp values near the
-- triple point.
--
-- THE TRIPLE SPELLING, because the line has to be right at 94 K:
--   Psat(94) = 0.00114 * exp((14690 / 8.3145) * (1/90.37 - 1/94))
--            = 0.00114 * exp(0.7550) = 2.43 Pa  (real about 3 Pa)
-- A boil anchor at 184.6 K would put 10 Pa there, about three times the
-- real figure, because L is held constant across 90 K. The price is the
-- warm end: this line reaches 1 atm at 216.6 K, not 184.6 K, and at
-- 293 K a sealed bottle condenses ethane at 8.5 bar, not the real 37.6.
--
-- Flow is liquid ethane near 94 K, approximate (CRC).
return {
    id = "ethane",
    name = "ethane",
    molar_mass = 30.069,
    cv = { solid = 58.0, liquid = 68.5, gas = 44.2 },
    phase = {
        triple = { t = 90.37, kpa = 0.00114 },
        l_fus = 2859,
        l_vap = 14690,
        critical = 305.3,
    },
    density = { solid = 0.72, liquid = 0.65 },
    flow = { viscosity = 1.2, surface_tension = 31.0, contact_angle = 10 },
    color = "#C8D0D8",
    appearance = {
        liquid = { profile = "puddle", tint = "#3E4A55" },
        solid = { profile = "crystalline", tint = "#E4ECF0" },
    },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel): a sea's second row.
    relevance = 30,
    group = "volatile",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for ethane. A fuel, so any trace counts.
    hazard = { health = 1, fire = 4, instability = 0 },
}
