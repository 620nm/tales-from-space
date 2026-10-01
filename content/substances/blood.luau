-- Blood: what a wound leaves on the deck, and what the bloodstream
-- holder dissolves medicine into. A mixture, not a molecule, so the
-- mass, heat capacity and density are the shelf's D2 convention
-- (docs/CHEMISTRY.md) — with one deliberate choice inside it.
--
-- THE MASS IS LOAD-BEARING. A blood unit is a centilitre: 560 units
-- read 5.6 L (content/items/anatomy/human_chest.luau, mobs.dm:20). At
-- density 1.0 that is 10 g a unit, and the unit bridge says a unit is
-- 0.025 mol (the engine's docs/chemistry/tg-bridge.md) — so the mass
-- that makes both true at once is 10 / 0.025 = 400 g/mol. A spilled
-- unit deposits 0.025 mol and stands 10 mL on the tile, whichever end
-- of the arithmetic a reader starts from. Hemoglobin's real mass is
-- 64 000; this is not a measurement of anything.
--
-- It rests liquid and never transitions on its own: tg gives blood no
-- phase curve, so `unmodeled` is the port, not a placeholder. It
-- metabolizes fast so it disappears fast (other_reagents.dm:5): tg's
-- 12.5 x REAGENTS_METABOLISM (mobs.dm:505) through this engine's own
-- 0.005 mol a tick is 0.0625.
--
-- tg: /datum/reagent/blood, `color = "#C80000"`
-- (code/modules/reagents/chemistry/reagents/other_reagents.dm:4). The
-- deck-pool red #AA1010 is the DECAL's, not this file's
-- (code/__DEFINES/colors.dm:225): a beaker of blood and a pool of it
-- are two different tg colours and stay two here.
local content = {
    id = "blood",
    name = "blood",
    molar_mass = 400.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    density = { liquid = 1.0 },
    -- How it flows (docs/chemistry/substances.md, `flow`). Whole
    -- blood at body temperature is about four times water's viscosity
    -- (0.04 Poise, the hyperphysics viscosity table) and blood is
    -- shear-thinning, so a spill's effective figure is lower — filed
    -- as a round 4. Surface tension 0.058 N/m (whole blood, standard
    -- college-physics figure). The contact angle is a judgment about
    -- a painted deck: blood wets better than water, so lower.
    flow = {
        viscosity = 4.0,
        surface_tension = 58.0,
        contact_angle = 60,
    },
    -- What it looks like through glass (tg: other_reagents.dm:4).
    color = "#C80000",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`). Blood is not a
    -- poison, a fuel or an oxidizer; the hazard of a pool of it is
    -- what it says about the shift, which is not a placard's business.
    hazard = { health = 0, fire = 0, instability = 0 },
    -- A bench substance like the catalysts, filed under Other:
    -- nothing scrubs it, nothing breathes it, and no dispenser pours it.
    group = "other",
    -- No `metabolism_rate` line would take the loader's 0.005; the
    -- shelf writes its numbers (tg-bridge.md D2).
    metabolism_rate = 0.0625,
}

return content
