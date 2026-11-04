return {
    id = "cold_outdoors",
    name = "Cold outdoors",
    kind = "terrestrial",
    meets = { "gravity" },
    gravity_m_s2 = 9.80665,
    sink_k = 259.15,
    insolation = 0,
    surface_temperature_k = 259.15,
    atmosphere = { blend = "refrigerated_air", air_half_life_s = 60, heat_half_life_s = 120 },
    -- The ground generated under a map: `surface` tops each column, `deep`
    -- lies under it, and a map's `rock` hint (rosters/ground_roles.luau) is
    -- the bedrock named here.
    ground = { surface = "sheet_ice", deep = "basalt_ground", rock = "basalt_ground" },
    sides_open_from = 0,
}
