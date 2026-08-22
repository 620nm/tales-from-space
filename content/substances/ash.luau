-- Ash: what is left when oil has been cooked. The one product on this
-- shelf that a room-temperature bench cannot reach -- its recipe wants
-- 480 K, which is what the reaction chamber is FOR.
--
-- Fictional, so the numbers are the shelf's convention: a round mass
-- and 100 J/mol/K (docs/CHEMISTRY.md, D2). Ash is not a compound, it is
-- a leftover, and pretending to know its molar mass would be worse than
-- admitting the number is a placeholder.
-- tg: /datum/reagent/ash (other_reagents.dm:2300).
return {
    id = "ash",
    name = "ash",
    molar_mass = 100.0,
    cv = 100.0,
    -- What it looks like through glass (tg: other_reagents.dm:2303).
    color = "#515151",
}
