-- Methane: CH4, the cold world's damp air, half its seas and its fuel.
--
-- interactions we use:
--   CH4 + 2 O2 -> CO2 + 2 H2O (methane_fire)
-- interactions which require catalysts:
--   CH4 -> C + 2 H2, catalyst iron (methane_pyrolysis)
-- interactions we know exist but don't need:
--   methane clathrate in water ice: no substance holds a gas inside a
--     solid's lattice, so the crust is plain ice
--   CH4 + H2O -> CO + 3 H2: steam reforming, with the water-gas shift
--     after it, needs CO, which the pack has no substance for;
--     pyrolysis is the hydrogen route
--   CH4 + CO2 -> 2 CO + 2 H2: dry reforming needs CO
--   2 CH4 + O2 -> 2 CO + 4 H2: partial oxidation needs CO; a lean fire
--     here burns all the way to CO2
--   CH4 + Cl2 -> CH3Cl + HCl: chlorination needs ultraviolet light and
--     two products the pack lacks, so chlorine and methane are inert
--     together
--   CH4 + 4 F2 -> CF4 + 4 HF: violent in reality; no CF4 or HF
--     substance, so fluorine and methane are inert together
--   sodium or potassium in liquid CH4: inert in reality too, recorded
--     so nobody adds it
--   methane failing to burn outside its 5-15 % flammability limits: a
--     reaction has no mixture-fraction gate, so the fire's ignition
--     latch and rate ramp stand in for the limits
--
-- Numbers are the NIST WebBook's for methane (C74828): triple point
-- 90.67 K at 11.69 kPa, normal boiling point 111.7 K, critical
-- temperature 190.6 K, heat of vaporization 8.17 kJ/mol at 111.7 K,
-- heat of fusion 0.939 kJ/mol. Liquid density 0.42 g/mL at the
-- boiling point; the solid's 0.49 is approximate (CRC). Gas cv 27.4 is
-- the 298 K cp of 35.7 less R; the condensed cv figures are
-- approximate cp values near the triple point.
--
-- THE TRIPLE SPELLING, because the cold world sits at 94 K, three
-- kelvin above the anchor, where a constant-L line is at its best:
--   Psat(94) = 11.69 * exp((8170 / 8.3145) * (1/90.67 - 1/94))
--            = 11.69 * exp(0.3839) = 17.16 kPa
-- NIST's Antoine fit (Prydz & Goodwin 1972) gives 17.85 kPa.
-- So the world's 7.5 kPa of methane is about 44 % "humidity" and stays
-- gas. A boil anchor would give 19.4 kPa. The price is the far end:
-- the line reaches 1 atm at 113.2 K, 1.5 K above the real boiling point.
--
-- Flow is liquid methane near 94 K, approximate (CRC): thin and
-- wetting, it runs further than water.
return {
    id = "methane",
    name = "methane",
    molar_mass = 16.043,
    cv = { solid = 43.0, liquid = 54.0, gas = 27.4 },
    phase = { triple = { t = 90.67, kpa = 11.69 }, l_fus = 939, l_vap = 8170, critical = 190.6 },
    density = { solid = 0.49, liquid = 0.42 },
    flow = { viscosity = 0.18, surface_tension = 17.0, contact_angle = 10 },
    color = "#C8D0D8",
    -- Clear as water in a bottle; a sea of it reads dark under a dim sky.
    appearance = {
        liquid = { profile = "puddle", tint = "#3E4A55" },
        solid = { profile = "crystalline", tint = "#E4ECF0" },
    },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel): a cold world's air and
    -- seas are made of it.
    relevance = 60,
    group = "volatile",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for methane. A fuel, so any trace counts.
    hazard = { health = 2, fire = 4, instability = 0 },
}
