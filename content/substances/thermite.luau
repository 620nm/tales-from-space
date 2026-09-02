-- Thermite: aluminium, iron and oxygen. In tg you paint it on a wall
-- and light it; walls are structures here and burning one through is
-- not ported, so what thermite is today is the recipe's third leg --
-- the one that needs all THREE reactants and does nothing at all with
-- two of them, which is what makes it the gate the specs watch.
--
-- Fictional, so the numbers are the shelf's convention: a plausible
-- mass and the flat 100 J/mol/K (docs/CHEMISTRY.md, D2).
-- tg: /datum/reagent/thermite (pyrotechnic_reagents.dm:2).
return {
    id = "thermite",
    name = "thermite",
    molar_mass = 90.0,
    cv = 100.0,
    phase = { unmodeled = "solid" },
    -- 4.0 g/mL: between aluminium (2.70) and iron oxide (5.24), which
    -- is what it is a mixture of. A stated convention (D2).
    density = { solid = 4.0 },
    -- What it looks like through glass (tg: pyrotechnic_reagents.dm:7).
    color = "#550000",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- Fictional mixture: hard to light and violent once lit.
    hazard = { health = 1, fire = 1, instability = 3 },
}
