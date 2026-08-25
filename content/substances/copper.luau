-- Copper: the wiring metal, and a dispenser button. Nothing in this
-- pack's reaction roster is made out of it yet -- tg spends it on
-- synthflesh and teslium -- so what it is here is a leg waiting for the
-- recipe that names it, which is the deal every element on the shelf
-- got.
--
-- Real molar mass and the real molar heat capacity (Cu, 24.4
-- J/(mol*K), which is Dulong-Petit's 3R almost exactly), with an
-- authored `unmodeled` rest phase per D2 (docs/CHEMISTRY.md): copper
-- melts at 1358 K, which no bench reaches, so a curve here would answer
-- a question nobody asked.
-- tg: /datum/reagent/copper (other_reagents.dm:996).
return {
    id = "copper",
    name = "copper",
    molar_mass = 63.55,
    cv = 24.4,
    phase = { unmodeled = "solid" },
    -- Real copper, 8.96 g/mL. Geometry caps a reaction by the free
    -- shell volume (docs/MATTER.md 5), so the density is what decides
    -- how much of it a beaker holds.
    density = { solid = 8.96 },
    -- What it looks like through glass (tg: other_reagents.dm:999).
    color = "#6E3B08",
}
