-- Sulphuric acid: H2SO4, tg's `/datum/reagent/toxin/acid`. A dispenser
-- button and one of the two legs aiuri stands on
-- (reactions/aiuri.luau).
--
-- THE NAME IS THE MOLECULE. tg files this under toxins and calls the
-- datum `acid`, which is a category rather than a substance; there is
-- one id per molecule here (D3), and the molecule is sulphuric acid.
-- The spelling is the American one because the id is a key and the
-- name beside it is what a player reads.
--
-- Real molar mass, real liquid molar heat capacity (H2SO4, 138.9
-- J/(mol*K)) and real density, with an authored `unmodeled` rest phase
-- per D2 (docs/CHEMISTRY.md): concentrated acid boils at 610 K and
-- decomposes doing it, which is chemistry this engine has no rule for.
--
-- What it does NOT do here is corrode: tg's acid eats armour, melts
-- items and burns whoever it splashes, all of which is exposure
-- gameplay this pack has no seam for yet. It is a reagent leg until
-- then, and saying so is better than half a mechanism.
-- tg: /datum/reagent/toxin/acid (toxin_reagents.dm:1255).
return {
    id = "sulfuric_acid",
    name = "sulphuric acid",
    molar_mass = 98.08,
    cv = 138.9,
    phase = { unmodeled = "liquid" },
    -- Real concentrated acid, 1.83 g/mL.
    density = { liquid = 1.83 },
    -- How it flows (docs/chemistry/substances.md, `flow`). Concentrated
    -- acid is SYRUP: two dozen times water's viscosity, so it takes the
    -- same spill two dozen times as long to level out. The numbers are
    -- the 96-98 % band and approximate; there is no one viscosity for a
    -- liquid whose strength is a range.
    flow = {
        -- mPa*s at 20 C (CRC Handbook 97th ed. / NIST WebBook).
        viscosity = 24.0,
        -- mN/m at 20 C (CRC Handbook 97th ed. / NIST WebBook).
        surface_tension = 55.0,
        -- Degrees on a painted deck: a content judgment, not a measurement.
        contact_angle = 60,
    },
    -- What it looks like through glass (tg: toxin_reagents.dm:1258).
    color = "#00FF32",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for sulfuric acid, W included: it boils what you dilute it with.
    hazard = { health = 3, fire = 0, instability = 2, special = "water_reactive" },
}
