-- Chlorine: half of table salt, and the reason a chem bench smells.
-- tg's reagent is an atom rather than Cl2 (its salt recipe is 1:1 with
-- sodium, others.dm:45), so the mass is one atom's and the specific
-- heat is Dulong-Petit's -- D2 in docs/reagents.md.
-- tg: /datum/reagent/chlorine (other_reagents.dm:1087).
return {
    id = "chlorine",
    name = "chlorine",
    molar_mass = 35.45,
    cv = 25.0,
    -- What it looks like through glass (tg: other_reagents.dm:1090).
    color = "#FFFB89",
}
