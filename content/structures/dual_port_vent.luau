-- Two independent mains: intake on layer 2, effluent on layer 4.
return {
    id = "dual_port_vent",
    name_label = "lunatic/tfs:entity.dual_port_vent.name",
    name = "dual-port air vent",
    sprite = "dual_port_vent_off",
    script = "dual_port_vent",
    ui = { modules = { "vent" } },
    link = { network_interface = true, role = "endpoint", class = "atmos" },
    dense = false,
    states = { "off", "blowing", "siphoning" },
    state_sprites = { blowing = "dual_port_vent_blowing", siphoning = "dual_port_vent_siphoning" },
    atmos = {
        device = "vent", port_layers = { 2, 4 }, on = false,
        positions = { "off", "blowing", "siphoning" },
        target_kpa = 101.325, release_below_kpa = 101.325, siphon_above_kpa = 109.431,
    },
    build = {
        on = { "floor", "plating" }, from_item = "dual_port_vent_fitting",
        tool = "wrench", secs = 2.0,
        start = "lunatic/tfs:entity.dual_port_vent.build.start",
        done = "lunatic/tfs:entity.dual_port_vent.build.done",
    },
    transitions = { {
        tool = "wrench", secs = 2.0, gone = true,
        yields = { dual_port_vent_fitting = 1 },
        start = "lunatic/tfs:entity.dual_port_vent.remove.start",
        done = "lunatic/tfs:entity.dual_port_vent.remove.done",
    } },
}
