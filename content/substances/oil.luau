-- Oil: heavier than welding fuel and made out of it, and the ONLY way
-- to ash, which is the only way to lye. The chain the heater exists
-- for.
--
-- Fictional, so the numbers are convention rather than measurement
-- (docs/CHEMISTRY.md, D2): a plausible hydrocarbon mass and the shelf's
-- flat 100 J/mol/K. Nothing here is claiming to be a real substance.
--
-- It burns, because tg's does: `burning_temperature = 1200` ("Oil is
-- crude") and `burning_volume = 0.05` ("but has a lot of hydrocarbons",
-- other_reagents.dm:1974-1975), through the unit bridge and the flame's
-- half-second pass:
--   0.05 u x 0.025 mol/u / 2 s x 0.5 s = 0.0003125 mol per pass
-- Cooler than welding fuel and spent a quarter as fast -- a long, dirty
-- little fire, which is exactly tg's two comments.
-- tg: /datum/reagent/fuel/oil (other_reagents.dm:1969).
return {
    id = "oil",
    name = "oil",
    molar_mass = 170.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    -- 0.9 g/mL, a light oil. Convention, not measurement (D2).
    density = { liquid = 0.9 },
    burn = { k = 1200, rate = 0.0003125 },
    -- What it looks like through glass (tg: other_reagents.dm:1972).
    color = "#2D2D2D",
}
