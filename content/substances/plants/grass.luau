-- Grass: the living sward over a meadow, a thin coat of real matter in the
-- cell (the `grass` cover, terrain.luau), drawn by the `grass` look and burnt by
-- reactions/grass_fire.luau.
--
-- tg has no grass reagent, so the numbers are real plant matter. One mole
-- is one cellulose unit, C6H10O5 at 162.14 g/mol; dry plant matter holds
-- about 1.3 J/(g*K), which is 211 J/(mol*K). 0.3 g/mL is a sward, leaf and
-- the air between, not packed fiber: a chosen figure. Grass does not melt.
return {
    id = "grass",
    name = "grass",
    molar_mass = 162.14,
    cv = 211.0,
    phase = { unmodeled = "solid" },
    density = { solid = 0.3 },
    -- The terrestrial art's grass tint (tools/art/terrestrial/plates).
    color = "#86C44A",
    appearance = { solid = "grass" },
    -- NFPA 704 for dry vegetation: burns once preheated.
    hazard = { health = 0, fire = 1, instability = 0 },
}
