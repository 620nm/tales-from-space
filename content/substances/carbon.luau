-- Carbon: what a grinder gets out of anything burnt, and one leg of
-- three recipes (oil, lye, carbon dioxide). Graphite's specific heat,
-- which is the one element on this shelf where the real number is
-- memorable and well under Dulong-Petit.
-- tg: /datum/reagent/carbon (other_reagents.dm:1071).
return {
    id = "carbon",
    name = "carbon",
    molar_mass = 12.011,
    cv = 8.5,
    phase = { unmodeled = "solid" },
    -- Graphite, 2.27 g/mL (real).
    density = { solid = 2.27 },
    -- What it looks like through glass (tg: other_reagents.dm:1074).
    color = "#1C1300",
}
