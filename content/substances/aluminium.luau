-- Aluminium: thermite's fuel. Spelled tg's way (tg says "aluminium",
-- not "aluminum"). Real mass, real molar heat capacity.
-- tg: /datum/reagent/aluminium (other_reagents.dm:1352).
return {
    id = "aluminium",
    name = "aluminium",
    molar_mass = 26.98,
    cv = 24.2,
    phase = { unmodeled = "solid" },
    -- What it looks like through glass (tg: other_reagents.dm:1355).
    color = "#A8A8A8",
}
