-- Open ground under a temperate sky: 20 C air at one atmosphere over bare
-- soil. `cold_outdoors` with the weather turned to a spring day.
--
-- The sky is in balance with its ground: `sink_k` equals
-- `surface_temperature_k` and there is no sun, so a map of dry ground
-- sleeps. A sink colder than the surface keeps every outdoor cell
-- radiating into air that ambient refills, and the map never rests.
--
-- No mode rolls this profile: a roll takes it by tag, and no map carries
-- the tag yet.
return {
    id = "warm_outdoors",
    name = "Warm outdoors",
    kind = "terrestrial",
    substrate = "ground",
    gravity_m_s2 = 9.80665,
    sink_k = 293.15,
    insolation = 0,
    surface_temperature_k = 293.15,
    atmosphere = { blend = "breathable_air", air_half_life_s = 60, heat_half_life_s = 120 },
    -- What a blank outdoor tile is made of.
    material = "soil_ground",
    sides_open_from = 0,
}
