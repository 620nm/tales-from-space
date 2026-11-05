-- Nitrogen: the other four fifths of ordinary air.
--
-- interactions we use:
--   N2 + 3 H2 -> 2 NH3 (ammonia)
-- interactions we know exist but don't need:
--   N2 dissolving in liquid CH4: the engine has no gas solubility, so a
--     cold sea holds none of the nitrogen it sits under
--
-- Physics: molar mass 28 g/mol, and gas cv 20 J/(mol·K), tg's
-- `specific_heat` verbatim (gas_types.dm, /datum/gas/nitrogen), because
-- the atmos column was tuned against it.
--
-- THE DIAGRAM, a departure from tg, which models no liquid nitrogen:
-- NIST WebBook (C7727379): triple point 63.14 K at 12.52 kPa (taken as
-- the melting point), normal boiling point 77.34 K, critical temperature
-- 126.19 K, heat of vaporization 5.6 kJ/mol at 77 K; CRC: heat of
-- fusion 0.72 kJ/mol. Liquid density 0.807 g/mL at the boiling point;
-- the solid's 1.03 is approximate (CRC). Condensed cv figures are
-- approximate cp values near the boiling point.
--
-- THE BOIL SPELLING, like oxygen's, so the line is right near 94 K:
--   Psat(94) = 101.325 * exp((5600 / 8.3145) * (1/77.34 - 1/94))
--            = 101.325 * exp(1.5435) = 474 kPa
-- NIST's Antoine fit (Edejer & Thodos 1967) gives 503 kPa.
-- So a cold world's 1.5 bar of nitrogen is far from condensing: it would
-- liquefy only below 81.0 K. A triple anchor would give 415 kPa. At a
-- thermomachine's 73.15 K floor the line is at 61.5 kPa, so the 79 kPa
-- nitrogen share of station air liquefies there. Above 126.19 K nothing
-- condenses it.
--
-- Nothing declares it breathable, which is the point of the column
-- being a declaration: a body draws four fifths of every lungful out of
-- this and keeps none of it, and the engine needs no rule saying so.
--
-- tg: /datum/reagent/nitrogen, `color = COLOR_GRAY`
-- (other_reagents.dm:1018).
return {
    id = "n2",
    name = "nitrogen",
    molar_mass = 28.0,
    cv = { solid = 46.0, liquid = 56.0, gas = 20.0 },
    phase = { melt = 63.14, boil = 77.34, l_fus = 720, l_vap = 5600, critical = 126.19 },
    density = { solid = 1.03, liquid = 0.807 },
    -- Liquid nitrogen near 77 K, approximate (CRC).
    flow = { viscosity = 0.158, surface_tension = 8.9, contact_angle = 5 },
    color = "#808080",
    -- Clear as a liquid; its frost is white.
    appearance = {
        liquid = { profile = "puddle", tint = "#D8E2EA" },
        solid = { profile = "crystalline", tint = "#F0F4F6" },
    },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). The other four fifths of
    -- ordinary air.
    relevance = 90,
    -- The other four fifths of ordinary air.
    group = "atmospheric",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for nitrogen.
    -- Breathable air is 79% nitrogen, so only a richer room is an asphyxiant.
    hazard = { health = 0, fire = 0, instability = 0, special = "asphyxiant", above = 0.85 },
}
