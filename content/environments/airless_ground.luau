return {
    id = "airless_ground",
    name = "Airless ground",
    kind = "terrestrial",
    meets = { "gravity" },
    gravity_m_s2 = 9.80665,
    sink_k = 2.7,
    insolation = 0,
    surface_temperature_k = 259.15,
    -- The ground generated under a map: `surface` tops each column, `deep`
    -- lies under it, and a map's `rock` hint (rosters/ground_roles.luau) is
    -- the bedrock named here.
    ground = { surface = "basalt_ground", deep = "basalt_ground", rock = "basalt_ground" },
    sides_open_from = 0,
}
