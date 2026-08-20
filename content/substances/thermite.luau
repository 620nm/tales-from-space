-- Thermite: aluminium, iron and oxygen. In tg you paint it on a wall
-- and light it; walls are structures here and burning one through is
-- not ported, so what thermite is today is the recipe's third leg --
-- the one that needs all THREE reactants and does nothing at all with
-- two of them, which is what makes it the gate the specs watch.
--
-- Fictional, so the numbers are the shelf's convention: a plausible
-- mass and the flat 100 J/mol/K (docs/reagents.md, D2).
-- tg: /datum/reagent/thermite (pyrotechnic_reagents.dm:2).
return {
    id = "thermite",
    name = "thermite",
    molar_mass = 90.0,
    cv = 100.0,
}
