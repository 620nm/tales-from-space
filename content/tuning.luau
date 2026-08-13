-- Gameplay-feel constants, tunable to taste (docs/power.md). Missing
-- fields fall back to the engine's hard-coded defaults — and the test
-- suite pins THOSE defaults, so tuning here never breaks tests.
return {
    -- How far an appliance's power cord reaches, in path cells (never
    -- through walls; closed doors count as walls). Engine default: 6.
    cord_range = 6,
}
