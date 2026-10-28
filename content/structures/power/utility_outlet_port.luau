-- A flush floor socket with a scripted cover and three independent
-- cable-layer lamps. The cover never changes electrical delivery.
-- Layer states and feed selection follow the engine's
-- docs/content-schema/fixture-states.md and docs/power/topology.md.
return {
    id = "utility_outlet_port",
    visual_layer = "fixture",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.utility_outlet_port.name",
    name = "utility outlet port",
    -- The closed cover is the default. The engine keeps each cable-layer
    -- lamp independent from the selected cover state.
    sprite = "utility_outlet_port",
    states = { "closed", "open" },
    state = "closed",
    state_sprites = {
        closed = "utility_outlet_port",
        open = "utility_outlet_port_open",
    },
    fixture = "Outlet",
    script = "utility_outlet_port",
    actions = {
        {
            id = "toggle_cover",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:action.utility_outlet_port.toggle_cover",
            held = { fact = "held.present", value = "false" },
        },
    },
    appearance = {
        channels = {
            l1 = {
                disconnected = "uop_wire_1_disconnected",
                inactive = "uop_wire_1_inactive",
                starved = "uop_wire_1_starved",
                emergency = "uop_wire_1_emergency",
                nominal = "uop_wire_1_nominal",
            },
            l2 = {
                disconnected = "uop_wire_2_disconnected",
                inactive = "uop_wire_2_inactive",
                starved = "uop_wire_2_starved",
                emergency = "uop_wire_2_emergency",
                nominal = "uop_wire_2_nominal",
            },
            l3 = {
                disconnected = "uop_wire_3_disconnected",
                inactive = "uop_wire_3_inactive",
                starved = "uop_wire_3_starved",
                emergency = "uop_wire_3_emergency",
                nominal = "uop_wire_3_nominal",
            },
        },
    },
    category = "power",
    examine = {
        flavor = "A flush circular metal fitting in the deck, with a hinged "
            .. "cover over one recessed socket. Three lamps report the "
            .. "independent state of each power layer beneath the floor.",
    },
}
