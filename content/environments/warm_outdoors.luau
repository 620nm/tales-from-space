-- Open ground under a temperate sky: 20 C air at one atmosphere over bare
-- soil. `cold_outdoors` with the weather turned to a spring day.
--
-- The sky is in balance with its ground: `sink_k` equals
-- `surface_temperature_k` and there is no sun, so a map of dry ground
-- sleeps. A sink colder than the surface keeps every outdoor cell
-- radiating into air that ambient refills, and the map never rests.
--
-- The modes roll this profile as a ground fallback; a terrestrial map that
-- pins `surface_temperature_k: Exact(293.15)` gets it rather than the cold.
return {
    id = "warm_outdoors",
    name = "Warm outdoors",
    kind = "terrestrial",
    meets = { "gravity" },
    gravity_m_s2 = 9.80665,
    sink_k = 293.15,
    insolation = 0,
    surface_temperature_k = 293.15,
    atmosphere = { blend = "breathable_air", air_half_life_s = 60, heat_half_life_s = 120 },
    -- The ground generated under a map: `surface` tops each column, `deep`
    -- lies under it, and a map's `rock` hint (rosters/ground_roles.luau) is
    -- the bedrock named here.
    ground = { surface = "soil_ground", deep = "basalt_ground", rock = "silica_ground" },
    sides_open_from = 0,
}
