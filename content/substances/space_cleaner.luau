-- Space cleaner: ammonia and water, and the reason a janitor talks to
-- a chemist. What it DOES to a dirty floor waits on decals; what it is
-- is here, and it is two buttons and a beaker.
--
-- Fictional, so the numbers are the shelf's convention (docs/CHEMISTRY.md,
-- D2): a plausible mass for a detergent and the flat 100 J/mol/K.
-- tg: /datum/reagent/space_cleaner (other_reagents.dm:1430).
return {
    id = "space_cleaner",
    name = "space cleaner",
    molar_mass = 110.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    -- 1.0 g/mL: it is mostly water. Convention (D2).
    density = { liquid = 1.0 },
    -- What it looks like through glass (tg: other_reagents.dm:1433).
    color = "#A5F0EE",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- An ammonia detergent: harmful, and nothing catches.
    hazard = { health = 2, fire = 0, instability = 0 },
}
