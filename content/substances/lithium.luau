-- Lithium: the lightest metal there is, and a dispenser button. tg
-- makes synaptizine out of it; that recipe waits on a substance file
-- for its product, so what lithium is here is the leg that will be
-- ready when it lands.
--
-- Real molar mass and the real molar heat capacity (Li, 24.9
-- J/(mol*K)), with an authored `unmodeled` rest phase per D2
-- (docs/CHEMISTRY.md): lithium melts at 454 K, which the reaction
-- chamber does reach -- but a molten alkali metal is a mechanism
-- nobody has written, and a curve that produces a phase no rule reads
-- is a claim without a consequence.
-- tg: /datum/reagent/lithium (other_reagents.dm:1156).
return {
    id = "lithium",
    name = "lithium",
    molar_mass = 6.94,
    cv = 24.9,
    phase = { unmodeled = "solid" },
    -- Real lithium, 0.534 g/mL: it floats on water, which is the one
    -- thing everybody knows about it.
    density = { solid = 0.534 },
    -- What it looks like through glass (tg: other_reagents.dm:1159,
    -- COLOR_GRAY).
    color = "#808080",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for lithium metal, W included.
    hazard = { health = 3, fire = 2, instability = 2, special = "water_reactive" },
}
