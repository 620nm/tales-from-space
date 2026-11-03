-- Moss: a low carpet over damp ground, a thin coat of real matter in the
-- cell (blends/moss_carpet.luau), drawn by the `moss` look and burnt by
-- reactions/moss_fire.luau.
--
-- The same plant chemistry as grass.luau (one cellulose unit a mole,
-- 211 J/(mol*K)); tg has no moss reagent. 0.2 g/mL is a spongy mat, a
-- chosen figure. Moss does not melt.
return {
    id = "moss",
    name = "moss",
    molar_mass = 162.14,
    cv = 211.0,
    phase = { unmodeled = "solid" },
    density = { solid = 0.2 },
    -- The terrestrial art's moss tint (tools/art/terrestrial/plates).
    color = "#5A9842",
    appearance = { solid = "moss" },
    -- NFPA 704 for dry vegetation: burns once preheated.
    hazard = { health = 0, fire = 1, instability = 0 },
}
