-- The surface of Mars: 210 K, 3.72 m/s2, a few hundred pascals of carbon
-- dioxide over bare basalt. Real figures (NASA Mars fact sheet: surface
-- gravity 3.71 to 3.73 m/s2, mean surface temperature 210 K), not tg's.
--
-- Balanced like `warm_outdoors`: `sink_k` equals `surface_temperature_k`
-- and `insolation` is 0, so a map of dry ground sleeps instead of
-- radiating into a sky that keeps refilling.
--
-- No mode rolls this profile yet.
return {
    id = "mars_surface",
    name = "Mars surface",
    kind = "terrestrial",
    meets = { "gravity" },
    gravity_m_s2 = 3.72,
    sink_k = 210.0,
    insolation = 0,
    surface_temperature_k = 210.0,
    atmosphere = { blend = "thin_co2_air", air_half_life_s = 60, heat_half_life_s = 120 },
    -- The ground generated under a map: `surface` tops each column, rock
    -- (`deep`) lies under it.
    ground = { surface = "basalt_ground", deep = "basalt_ground" },
    sides_open_from = 0,
}
