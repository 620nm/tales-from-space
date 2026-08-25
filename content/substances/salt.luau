-- Table salt: the first thing anybody makes on a chem bench, and the
-- first thing that needs a bottle rather than a beaker -- its other
-- half is liquid chlorine, which only stands still under a lid
-- (reactions/salt.luau).
--
-- Real molar mass and real molar heat capacity (NaCl, 50.5 J/mol/K),
-- but UNMODELED: real salt melts at 1074 K, which no bench reaches and
-- which would make a bell that already runs at room temperature answer
-- a question nobody asked. Feel wins; recorded as a deliberate
-- departure in docs/CHEMISTRY.md, D2.
-- tg: /datum/reagent/consumable/salt (food_reagents.dm:508).
return {
    id = "salt",
    name = "salt",
    molar_mass = 58.44,
    cv = 50.5,
    phase = { unmodeled = "solid" },
    -- Real halite, 2.17 g/mL. Geometry caps a reaction by the free
    -- shell volume (docs/MATTER.md 5), so what the product actually
    -- weighs decides how much salt a beaker can make.
    density = { solid = 2.17 },
    -- What it looks like through glass (tg: food_reagents.dm:511 (COLOR_WHITE)).
    color = "#FFFFFF",
}
