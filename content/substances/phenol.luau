-- Phenol: the first rung of the medicine trunk. Nothing heals with it
-- and nobody drinks it -- it is what libital and epinephrine are made
-- out of (reactions/phenol.luau, reactions/libital.luau,
-- reactions/epinephrine.luau), and the whole reason a chemist presses
-- chlorine into a bottle before anything else.
--
-- Real molar mass (C6H5OH) and real density, because it is a real
-- molecule and the density is load-bearing: geometry caps a reaction
-- by the free shell volume (D16, docs/MATTER.md 5), so what a product
-- WEIGHS decides how much of it a bottle can make. `cv = 100` is the
-- shelf's flat convention for a reagent whose real heat capacity is
-- not gameplay (D2, docs/CHEMISTRY.md), the same figure oil and ash
-- carry.
--
-- An authored `unmodeled` rest phase, and it is a DEPARTURE worth
-- naming: real phenol is a solid at room temperature (it melts at
-- 314 K). tg carries it as a liquid reagent, every recipe that names
-- it means the liquid, and a solid rung would make the trunk stop at
-- the first step for no gameplay anybody wanted. The convention wins
-- and this comment is the record of it.
-- tg: /datum/reagent/phenol (other_reagents.dm:2291).
return {
    id = "phenol",
    name = "phenol",
    molar_mass = 94.11,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    -- Real phenol, 1.07 g/mL.
    density = { liquid = 1.07 },
    -- What it looks like through glass (tg: other_reagents.dm:2294).
    color = "#E7EA91",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for phenol.
    hazard = { health = 4, fire = 2, instability = 0 },
}
