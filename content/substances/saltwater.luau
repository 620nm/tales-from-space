-- Salt water: what salt turns into the moment there is water beside it,
-- which is a real thing that a bench full of both discovers on its own.
--
-- tg carries it as its own reagent rather than as a mixture, so it is
-- one here too. Mass and specific heat are a BRINE's rather than either
-- ingredient's -- close to water, a shade heavier, a shade harder to
-- warm -- and Inert, because a solution has no single boiling point to
-- give it. Convention rather than measurement (docs/CHEMISTRY.md, D2).
-- tg: /datum/reagent/water/salt (other_reagents.dm:265).
return {
    id = "saltwater",
    name = "salt water",
    molar_mass = 30.0,
    cv = 80.0,
    -- What it looks like through glass (tg: other_reagents.dm:268, alpha 9d dropped).
    color = "#AAAAAA",
}
