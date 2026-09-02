-- Phosphorus: the red powder that burns readily. A dispenser button
-- and, for now, nothing else -- tg spends it on flash powder and
-- pyrotechnics, and explosives wait on cell-deposit effects
-- (docs/CHEMISTRY.md, Gaps).
--
-- Real molar mass and the real molar heat capacity (P, 23.8
-- J/(mol*K)), with an authored `unmodeled` rest phase per D2
-- (docs/CHEMISTRY.md). tg's description is the RED allotrope, which is
-- the one that sits in a jar rather than igniting in air, so the
-- density is red phosphorus's.
-- tg: /datum/reagent/phosphorus (other_reagents.dm:1141).
return {
    id = "phosphorus",
    name = "phosphorus",
    molar_mass = 30.97,
    cv = 23.8,
    phase = { unmodeled = "solid" },
    -- Red phosphorus, 2.34 g/mL.
    density = { solid = 2.34 },
    -- What it looks like through glass (tg: other_reagents.dm:1144).
    color = "#832828",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for RED phosphorus, which is what this file is.
    hazard = { health = 2, fire = 1, instability = 1 },
}
