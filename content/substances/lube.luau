-- Lube: water, silicon and oxygen, and in tg the single most reliable
-- way to make a corridor into a comedy. The slipping is deferred with
-- the rest of the floor effects; the recipe is not, because it is the
-- one on this shelf that consumes a builtin GAS as a liquid and so the
-- one that proves the two rosters are the same roster.
--
-- Fictional, so the numbers are the shelf's convention: a plausible
-- silicone mass and the flat 100 J/mol/K (docs/CHEMISTRY.md, D2).
-- tg: /datum/reagent/lube (other_reagents.dm:547).
return {
    id = "lube",
    name = "lube",
    molar_mass = 120.0,
    cv = 100.0,
    -- What it looks like through glass (tg: other_reagents.dm:550).
    color = "#009CA8",
}
