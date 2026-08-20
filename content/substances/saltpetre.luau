-- Saltpetre: potassium nitrate. tg feeds it to plants and puts it in
-- gunpowder; hydroponics and explosives are both deferred, so what it
-- is here is the one recipe on the shelf that takes three parts oxygen
-- and therefore the one that empties a beaker fastest.
--
-- Real molar mass and real molar heat capacity (KNO3), Inert per D2.
-- tg: /datum/reagent/saltpetre (other_reagents.dm:2537).
return {
    id = "saltpetre",
    name = "saltpetre",
    molar_mass = 101.10,
    cv = 95.1,
    -- What it looks like through glass (tg: other_reagents.dm:2540).
    color = "#60A584",
}
