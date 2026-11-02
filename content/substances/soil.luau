-- Soil: weathered mineral grains with a little organic matter. Mostly
-- silicate, so one mole here is one mole of oxide units at silica's
-- mass, the same stand-in basalt.luau makes for a rock mix.
--
-- Real-world values, not tg's (tg has no ground reagent): dry loam packs
-- to 1.1 to 1.5 g/mL, taken here as 1.3; dry mineral soil holds about
-- 0.8 J/(g*K), which at 60 g/mol is 48 J/(mol*K). Wet soil holds far
-- more, but water is its own substance and arrives as matter on top.
-- `unmodeled = "solid"`: soil does not melt on any map.
return {
    id = "soil",
    name = "soil",
    molar_mass = 60.0,
    cv = 48.0,
    phase = { unmodeled = "solid" },
    density = { solid = 1.3 },
    -- Dark loam.
    color = "#5C4033",
}
