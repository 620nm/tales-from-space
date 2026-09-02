-- Acetone: the solvent. One of epinephrine's four legs
-- (reactions/epinephrine.luau) and, in tg, the thing half the
-- chemistry tree is thinned with.
--
-- It is a RECIPE here rather than a button (reactions/acetone.luau),
-- which is a departure from tg's own shelf: acetone sits on tg's
-- upgrade tier (chem_dispenser.dm:82), and this pack promoted the
-- upgrade tier's ammonia, ash and saltpetre to the base shelf because
-- it has no upgrade parts. Acetone stayed off it because it HAS a
-- recipe, and a bench where the first medicine is two presses and a
-- stir is a bench with nothing to learn in it.
--
-- Real molar mass (C3H6O) and real density -- the density is
-- load-bearing, because geometry caps a reaction by the free shell
-- volume (D16). `cv = 100` is the shelf's flat convention for a
-- reagent whose real heat capacity is not gameplay (D2,
-- docs/CHEMISTRY.md), and the `unmodeled` rest phase is the same
-- decision: acetone boils at 329 K, which the reaction chamber
-- reaches, and a solvent that flashed off mid-synthesis is a mechanic
-- nobody asked for.
-- tg: /datum/reagent/acetone (other_reagents.dm:2315).
return {
    id = "acetone",
    name = "acetone",
    molar_mass = 58.08,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    -- Real acetone, 0.784 g/mL.
    density = { liquid = 0.784 },
    -- What it looks like through glass (tg: other_reagents.dm:2318).
    color = "#AF14B7",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for acetone: a solvent that flashes at -20 C.
    hazard = { health = 1, fire = 3, instability = 0 },
}
