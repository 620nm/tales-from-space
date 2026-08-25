-- Chlorine: half of table salt, and the reason a chem bench smells.
-- tg's reagent is an atom rather than Cl2 (its salt recipe is 1:1 with
-- sodium, others.dm:45), so the mass is one atom's and the specific
-- heat is Dulong-Petit's -- D2 in docs/CHEMISTRY.md.
--
-- The sequel is `cl2.luau`, the diatomic molecule with a real phase
-- curve on it. This file keeps tg's single atom so the salt recipe
-- keeps its arithmetic; heat a beaker of it past 420 K and
-- reactions/chlorine_gas.luau pairs it off into the gas, which is the
-- most dangerous thing this bench can make. Policy D3, docs/CHEMISTRY.md.
-- tg: /datum/reagent/chlorine (other_reagents.dm:1087).
return {
    id = "chlorine",
    name = "chlorine",
    molar_mass = 35.45,
    cv = 25.0,
    phase = { unmodeled = "liquid" },
    -- What it looks like through glass (tg: other_reagents.dm:1090).
    color = "#FFFB89",
}
