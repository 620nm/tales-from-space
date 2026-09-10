-- tg unary_devices/airlock_pump.dm:114-120: distro L4 and waste L2 share dir.
return {
    id = "airlock_pump",
    name_label = "lunatic/tfs:entity.airlock_pump.name",
    name = "external airlock pump",
    sprite = "airlock_pump_off",
    script = "airlock_pump",
    ui = { modules = { "vent" } },
    link = { network_interface = true, role = "endpoint", class = "atmos" },
    dense = false,
    states = { "off", "blowing", "siphoning" },
    state_sprites = { blowing = "airlock_pump_blowing", siphoning = "airlock_pump_siphoning" },
    atmos = {
        device = "vent", port_layout = "stacked", port_layers = { 4, 2 }, on = false,
        positions = { "off", "blowing", "siphoning" },
        target_kpa = 101.325, release_below_kpa = 101.325, siphon_above_kpa = 109.431,
    },
    build = {
        on = { "floor", "plating" }, from_item = "airlock_pump_fitting",
        tool = "wrench", secs = 2.0,
        start = "lunatic/tfs:entity.airlock_pump.build.start",
        done = "lunatic/tfs:entity.airlock_pump.build.done",
    },
    transitions = { {
        tool = "wrench", secs = 2.0, gone = true,
        yields = { airlock_pump_fitting = 1 },
        start = "lunatic/tfs:entity.airlock_pump.remove.start",
        done = "lunatic/tfs:entity.airlock_pump.remove.done",
    } },
}
