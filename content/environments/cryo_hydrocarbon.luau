-- A frozen world under a methane sky: 94 K, standard gravity, 1.5 bar of
-- nitrogen and methane over water ice, with liquid methane-ethane seas in
-- its basins. The pressure is harmless; the cold and the missing oxygen
-- are not.
--
-- Balanced like `mars_surface`: `sink_k` equals `surface_temperature_k` and
-- `insolation` is 0, so dry ground sleeps.
--
-- Two air layers (the engine's docs/gamemodes/air-layers.md). Level 0 and
-- up take `cryo_air`, 7.5 kPa of methane; level -1 and below, the basins
-- and seas, take `cryo_low_air`, 15 kPa, near its dew line, with HCN snow
-- falling on its open sky. Both are at 94 K, as every layer must be.
--
-- The snow's `extinction_per_m` is chosen from the sight it leaves.
-- Koschmieder: visibility V = 3.912 / sigma meters, and a tile is 1 m, so
-- about 4.5 tiles wants sigma = 3.912 / 4.5 = 0.87 per m. The engine caps
-- sight at floor(V) tiles: V = 3.912 / 0.87 = 4.50 m, four tiles at full
-- intensity (the engine's docs/sim/sight-extinction.md).
--
-- The snow falls 0.01 kg/m2/s (a chosen figure: 4 cm of solid frost an
-- hour at 0.9 g/mL) in 10 s batches, 0.1 kg a tile each, until a tile holds
-- 1 cm of condensed matter (cap_m): 9 kg, 90 batches, 15 minutes.
-- The upper air has no fallout: the snow is the low country's.
local SNOW = {
    blend = "hcn_snow",
    kg_per_m2_s = 0.01,
    interval_s = 10,
    cap_m = 0.01,
    extinction_per_m = 0.87,
    -- Pale frost-white with a warm cast; flakes 2 cm, falling at 1 m/s.
    look = { tint = "#E4E2D6", particle_m = 0.02, fall_m_s = 1.0, particles_per_m2 = 40 },
}

return {
    id = "cryo_hydrocarbon",
    name = "Cryo-hydrocarbon world",
    kind = "terrestrial",
    meets = { "gravity" },
    gravity_m_s2 = 9.80665,
    sink_k = 94.0,
    insolation = 0,
    surface_temperature_k = 94.0,
    atmosphere = {
        blend = "cryo_air",
        air_half_life_s = 60,
        heat_half_life_s = 120,
        strata = {
            { id = "lowland", at_or_below = -1, blend = "cryo_low_air", fallout = SNOW },
        },
    },
    -- The ground generated under a map: sheet ice on top, ice bedrock
    -- below and wherever a map's `rock` hint stands one up.
    ground = { surface = "sheet_ice", deep = "ice_bedrock", rock = "ice_bedrock" },
    sides_open_from = 0,
}
