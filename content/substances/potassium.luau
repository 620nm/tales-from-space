-- Potassium: saltpetre's metal, and in tg the other half of the oldest
-- joke in chemistry (potassium and water). That reaction is NOT ported
-- -- it is an explosion, and explosions are on the deferred list -- so
-- what this is today is a fertiliser component. Real mass, real molar
-- heat capacity.
-- tg: /datum/reagent/potassium (other_reagents.dm:1037).
return {
    id = "potassium",
    name = "potassium",
    molar_mass = 39.10,
    cv = 29.6,
    phase = { unmodeled = "solid" },
    -- Real potassium, 0.86 g/mL -- lighter than water, which is what
    -- the demonstration everybody remembers depends on.
    density = { solid = 0.86 },
    -- What it looks like through glass (tg: other_reagents.dm:1040).
    color = "#A0A0A0",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for potassium metal, W included.
    hazard = { health = 3, fire = 1, instability = 2, special = "water_reactive" },
}
