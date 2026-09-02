-- Silicon: what lube is made of, and what a ground-up circuit board
-- would be if grinders existed yet. Real mass, real molar heat
-- capacity.
-- tg: /datum/reagent/silicon (other_reagents.dm:1360).
return {
    id = "silicon",
    name = "silicon",
    molar_mass = 28.09,
    cv = 19.8,
    phase = { unmodeled = "solid" },
    -- Real silicon, 2.33 g/mL.
    density = { solid = 2.33 },
    -- What it looks like through glass (tg: other_reagents.dm:1363).
    color = "#A8A8A8",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for silicon powder.
    hazard = { health = 1, fire = 1, instability = 0 },
}
