-- Table salt: the first thing anybody makes on a chem bench, because
-- the two halves are one button each and the exotherm is visible.
--
-- Real molar mass and real molar heat capacity (NaCl, 50.5 J/mol/K),
-- but INERT: real salt melts at 1074 K, which no bench reaches and
-- which would make a bell that already runs at room temperature answer
-- a question nobody asked. Feel wins; recorded as a deliberate
-- departure in docs/CHEMISTRY.md, D2.
-- tg: /datum/reagent/consumable/salt (food_reagents.dm:508).
return {
    id = "salt",
    name = "salt",
    molar_mass = 58.44,
    cv = 50.5,
    -- What it looks like through glass (tg: food_reagents.dm:511 (COLOR_WHITE)).
    color = "#FFFFFF",
}
