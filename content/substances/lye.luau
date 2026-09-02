-- Lye: caustic soda. tg has two recipes for it and this pack takes the
-- one that starts from ash, because ash is something a bench MAKES
-- rather than something a dispenser hands out -- which is what turns a
-- shelf of buttons into a chain.
--
-- Real molar mass and real molar heat capacity (NaOH), with an
-- authored `unmodeled` rest phase for the same reason salt has one: it
-- melts at 596 K, well inside the heater's range, and a bench chemical
-- that puddles on the hotplate is a distraction from the chemistry.
-- docs/CHEMISTRY.md, D2.
-- tg: /datum/reagent/lye (other_reagents.dm:2552).
return {
    id = "lye",
    name = "lye",
    molar_mass = 40.00,
    cv = 59.5,
    phase = { unmodeled = "liquid" },
    -- 1.5 g/mL, a strong caustic solution. Convention (D2).
    density = { liquid = 1.5 },
    -- What it looks like through glass (tg: other_reagents.dm:2555).
    color = "#FFFFD6",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for sodium hydroxide; dissolving it boils the water.
    hazard = { health = 3, fire = 0, instability = 1, special = "water_reactive" },
}
