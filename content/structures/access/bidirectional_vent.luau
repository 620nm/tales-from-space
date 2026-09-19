-- tg unary_devices/airlock_pump.dm: distro L4 and waste L2 share dir (:114-120);
-- the process fills and siphons its turf and every atmos-adjacent one (:199-254).
-- Station crews also call it the 'dual-port vent' or 'equalization port'.
return {
    id = "bidirectional_vent",
    visual_layer = "fixture",
    energy_network = "power",
    -- tg's AREA_USAGE_ENVIRON, atmosmachinery.dm:18 (docs/POWER.md).
    load_class = "environment",
    name_label = "lunatic/tfs:entity.bidirectional_vent.name",
    name = "bidirectional vent",
    sprite = "bidirectional_vent_off",
    script = "bidirectional_vent",
    ui = { modules = { "vent" } },
    link = { network_interface = true, role = "endpoint", class = "atmos" },
    dense = false,
    states = { "off", "blowing", "siphoning" },
    state_sprites = { blowing = "bidirectional_vent_blowing", siphoning = "bidirectional_vent_siphoning" },
    atmos = {
        channel = "l3",
        network = "pipe",
        device = "vent",
        port_layout = "stacked",
        port_channels = { "l4", "l2" },
        on = false,
        positions = { "off", "blowing", "siphoning" },
        target_kpa = 101.325,
        release_below_kpa = 101.325,
        siphon_above_kpa = 109.431,
        -- tg airlock_pump.dm:207-254 works its turf and every atmos-adjacent one (:472-476).
        -- The tuned quantity is the fraction: volume_rate 2000 (:55) of a 2500 L turf
        -- (CELL_VOLUME, atmos_core.dm:152) moves 0.8 per process, and 800 L/s of our 1000 L
        -- tile keeps it, where copying 2000 would empty a tile twice over.
        spread = "adjacent",
        rate_lps = 800,
        max_rate_lps = 800,
    },
    build = {
        sound = "smash",
        on = { "component:station_base" },
        from_item = "bidirectional_vent_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "lunatic/tfs:entity.bidirectional_vent.build.start",
        done = "lunatic/tfs:entity.bidirectional_vent.build.done",
    },
    transitions = {
        {
            sound = "smash",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { bidirectional_vent_fitting = 1 },
            start = "lunatic/tfs:entity.bidirectional_vent.remove.start",
            done = "lunatic/tfs:entity.bidirectional_vent.remove.done",
        },
    },
}
