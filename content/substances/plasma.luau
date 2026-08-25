-- Plasma: the gas a station is built around holding away from itself.
--
-- Physics, verbatim from tg: molar mass 120 g/mol, cv 200 J/(mol·K)
-- (tg `specific_heat`, gas_types.dm, /datum/gas/plasma), and
-- `gas_only` — vanilla tg has no liquid plasma, and every fire number
-- ported in reactions/plasma_fire.luau assumes the gas column.
--
-- The heat capacity is the whole reason a plasma fire behaves the way
-- it does: ten times air's, so the same joules move the temperature a
-- tenth as far, and a fire in a plasma-rich room burns long rather than
-- hot.
--
-- `visible` is tg's MOLES_GAS_VISIBLE = 0.25 and
-- FACTOR_GAS_VISIBLE_MAX = 20: a quarter mole in a tile is the first
-- thing you can see, and twenty times that is full opacity. The
-- THRESHOLD is physics and the TINT is a decision about how to draw it,
-- which is why both are here and neither is in engine code — the purple
-- is the one the client has always drawn plasma in (0.75/0.35/0.95 in
-- the old renderer).
return {
    id = "plasma",
    name = "plasma",
    molar_mass = 120.0,
    cv = 200.0,
    phase = "gas_only",
    visible = { moles = 0.25, factor = 20, tint = "#BF59F2" },
    -- Poison to breathe: past the engine's line every breath costs TOX
    -- in proportion to how thick it is, with no clock (tg's
    -- `safe_plasma_max`).
    breath = { toxic = true },
    -- What a station is built to keep away from itself, as against what
    -- it is merely full of. Nothing in the sim branches on this yet; it
    -- is the substance's own word about itself, and the engine has no
    -- list of which gases frighten anybody.
    dangerous = true,
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel).
    relevance = 70,
    -- tg's `dangerous = TRUE` (gas_types.dm:111).
    group = "poison",
}
