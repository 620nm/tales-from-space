-- Silica: quartz, the rock under natural ground and the stuff sand is
-- made of. One mole is the formula unit SiO2.
--
-- Real values, not tg's (tg has no ground reagent): molar mass 60.08
-- g/mol; alpha-quartz density 2.65 g/mL; molar heat capacity 44.6
-- J/(mol*K) at 298 K (NIST-JANAF; for a solid Cv and Cp differ by under
-- one percent, so Cp stands in). `unmodeled = "solid"`: quartz melts near
-- 2000 K, which no map reaches, so a curve would answer a question
-- nobody asked (docs/CHEMISTRY.md, D2).
return {
    id = "silica",
    name = "silica",
    molar_mass = 60.08,
    cv = 44.6,
    phase = { unmodeled = "solid" },
    density = { solid = 2.65 },
    -- Pale grey quartz.
    color = "#C8C4BC",
}
