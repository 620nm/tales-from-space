-- Iron: thermite's oxide half, and in tg the thing you drink when you
-- have lost blood. The blood half waits on biology; the bench half is
-- here. Real mass, real molar heat capacity -- almost exactly
-- Dulong-Petit, which is what makes it the rule of thumb.
-- tg: /datum/reagent/iron (other_reagents.dm:1200).
return {
    id = "iron",
    name = "iron",
    molar_mass = 55.85,
    cv = 25.1,
    phase = { unmodeled = "solid" },
    -- Real iron, 7.87 g/mL.
    density = { solid = 7.87 },
    -- What it looks like through glass (tg: other_reagents.dm:1207).
    color = "#606060",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for iron powder.
    hazard = { health = 0, fire = 1, instability = 0 },
}
