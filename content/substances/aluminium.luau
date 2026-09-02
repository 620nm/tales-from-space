-- Aluminium: thermite's fuel. Spelled tg's way (tg says "aluminium",
-- not "aluminum"). Real mass, real molar heat capacity.
-- tg: /datum/reagent/aluminium (other_reagents.dm:1352).
return {
    id = "aluminium",
    name = "aluminium",
    molar_mass = 26.98,
    cv = 24.2,
    phase = { unmodeled = "solid" },
    -- Real aluminium, 2.70 g/mL: a mole of it is 10 mL of the beaker.
    density = { solid = 2.70 },
    -- What it looks like through glass (tg: other_reagents.dm:1355).
    color = "#A8A8A8",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for aluminium powder: the dust burns, the bar does not.
    hazard = { health = 0, fire = 1, instability = 1 },
}
