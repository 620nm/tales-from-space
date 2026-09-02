-- Saltpetre: potassium nitrate. tg feeds it to plants and puts it in
-- gunpowder; hydroponics and explosives are both deferred, so what it
-- is here is a SHELF reagent -- one of tg's own upgrade-tier dispenser
-- buttons (chem_dispenser.dm:81-88), which is where it comes from now
-- that no recipe makes it.
--
-- It used to be a recipe: 1 potassium + 1 nitrogen + 3 oxygen
-- (others.dm:776-778), four fifths of it permanent gas. A source
-- deposits what a substance IS and a gas over an open beaker is
-- refused (D19), so the recipe had nothing left to stand on and the
-- button it needed is the button it became.
--
-- Real molar mass and real molar heat capacity (KNO3), with an
-- authored `unmodeled` rest phase per D2 (docs/CHEMISTRY.md).
-- tg: /datum/reagent/saltpetre (other_reagents.dm:2537).
return {
    id = "saltpetre",
    name = "saltpetre",
    molar_mass = 101.10,
    cv = 95.1,
    phase = { unmodeled = "solid" },
    -- Real potassium nitrate, 2.11 g/mL.
    density = { solid = 2.11 },
    -- What it looks like through glass (tg: other_reagents.dm:2540).
    color = "#60A584",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for potassium nitrate, OX included.
    hazard = { health = 1, fire = 0, instability = 0, special = "oxidizer" },
}
