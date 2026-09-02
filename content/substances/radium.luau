-- Radium: the alkaline earth metal nobody should be holding. NOT on
-- the dispenser shelf, though tg lists it there -- a tap that pours
-- radium into an open beaker is not a thing a station's chemistry
-- bench should offer, and radiation is unmodeled here anyway, so the
-- button would be a hazard with no mechanism behind it. It arrives in
-- a bottle.
--
-- Real molar mass, and the heat capacity is Dulong-Petit's 3R = 24.9
-- J/(mol*K) -- the shelf's convention for an element whose measured
-- figure nobody needs (D2, docs/CHEMISTRY.md). An authored `unmodeled`
-- rest phase by the same decision: radium melts at 973 K, which the
-- chamber can reach and which no rule reads.
-- tg: /datum/reagent/uranium/radium (other_reagents.dm:1312).
return {
    id = "radium",
    name = "radium",
    molar_mass = 226.0,
    cv = 24.9,
    phase = { unmodeled = "solid" },
    -- Real radium, 5.5 g/mL.
    density = { solid = 5.5 },
    -- What it looks like through glass (tg: other_reagents.dm:1315).
    color = "#00CC00",
    -- A thing the station is built to keep away from itself.
    dangerous = true,
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for radium: the metal nobody should be holding.
    hazard = { health = 4, fire = 0, instability = 1, special = "radioactive" },
}
