-- Mercury: the metal that pours. A dispenser button, and the one
-- element on this shelf whose `unmodeled` rest phase is a LIQUID --
-- which is not a convenience but the fact everybody knows about it.
--
-- Real molar mass and the real molar heat capacity (Hg, 28.0
-- J/(mol*K)), with an authored `unmodeled` rest phase per D2
-- (docs/CHEMISTRY.md): mercury boils at 630 K, which the reaction
-- chamber reaches -- and mercury vapour is a genuinely lethal thing
-- that nothing here would do anything with, so a curve would be a
-- promise the game does not keep.
-- tg: /datum/reagent/mercury (other_reagents.dm:1045).
return {
    id = "mercury",
    name = "mercury",
    molar_mass = 200.59,
    cv = 28.0,
    phase = { unmodeled = "liquid" },
    -- Real mercury, 13.53 g/mL: the densest thing on this shelf by a
    -- long way, and a mole of it is fifteen millilitres.
    density = { liquid = 13.53 },
    -- How it flows (docs/chemistry/substances.md, `flow`). Mercury is
    -- about as runny as water and wets NOTHING: the enormous surface
    -- tension and an angle past a right angle make it bead, so it leaves
    -- a thick film and crawls a shorter way than water for all its
    -- weight. Chasing beads across a deck is the point.
    flow = {
        -- mPa*s at 20 C (CRC Handbook 97th ed. / NIST WebBook).
        viscosity = 1.526,
        -- mN/m at 20 C (CRC Handbook 97th ed. / NIST WebBook).
        surface_tension = 485.5,
        -- Degrees on a painted deck: a content judgment, not a measurement.
        contact_angle = 140,
    },
    -- What it looks like through glass (tg: other_reagents.dm:1048,
    -- COLOR_WEBSAFE_DARK_GRAY).
    color = "#484848",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for mercury; the vapour is the poison.
    hazard = { health = 3, fire = 0, instability = 0, special = "skull" },
}
