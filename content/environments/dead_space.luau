return {
    id = "dead_space",
    name = "dead space",
    kind = "space",
    substrate = "space",
    -- No field of its own: a running gravity battery gives its connected
    -- deck weight (structures/power/grav_smes.luau).
    gravity_m_s2 = 0,
    background = "space_backdrop",
    sink_k = 2.7,
    insolation = 0,
    surface_temperature_k = 293.15,
    beyond = { below = "empty", above = "empty" },
}
