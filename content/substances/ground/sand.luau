-- Sand: quartz grains lying loose. Chemically it is silica, so its mole
-- is silica's (60.08 g/mol, 44.6 J/(mol*K)); what differs is the BULK
-- density, because a cubic meter of sand is grains plus air between them.
--
-- Real-world values, not tg's: dry loose sand packs to 1.4 to 1.7 g/mL,
-- taken here as 1.6 (about 40% voids against quartz's 2.65). Ground is
-- measured per cubic meter of the tile, so the bulk figure is the one
-- that counts. `unmodeled = "solid"`: grains do not melt on any map.
return {
    id = "sand",
    name = "sand",
    molar_mass = 60.08,
    cv = 44.6,
    phase = { unmodeled = "solid" },
    density = { solid = 1.6 },
    -- Dry beach sand.
    color = "#D9C48F",
}
