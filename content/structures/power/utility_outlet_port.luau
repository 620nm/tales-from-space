-- A flush floor socket with a removable cap over three independent
-- cable-layer lamps. The cap hides the lamps and never changes electrical
-- delivery. Each lamp folds the engine's five layer states into this
-- pack's three pictures: disconnected; connected (a cable that is not
-- carrying); active (a cable that is, reserve included).
-- Layer states and feed selection follow the engine's
-- docs/content-schema/fixture-states.md and docs/power/topology.md.
return {
    id = "utility_outlet_port",
    visual_layer = "fixture",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.utility_outlet_port.name",
    name = "utility outlet port",
    -- The closed cap is the default. Each cable-layer lamp keeps its own
    -- reading whichever state the cap is in.
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
            id = "open",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:action.open",
            target = { fact = "target.state", value = "closed" },
            visible = { fact = "held.present", value = "false" },
        },
        {
            id = "close",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:action.close",
            target = { fact = "target.state", value = "open" },
            visible = { fact = "held.present", value = "false" },
        },
    },
    hover_connections = {
        relation = "energy_consumers",
        state = "open",
        styles = {
            active = {
                color = "#76C8AE",
                width = 0.055,
                head_length = 0.23,
                head_sweep = math.pi / 4,
                source_clearance = 0.20,
                target_clearance = 0.25,
                dash_length = 0,
                gap_length = 0,
            },
            inactive = {
                color = "#CFAB63",
                width = 0.055,
                head_length = 0.23,
                head_sweep = math.pi / 4,
                source_clearance = 0.20,
                target_clearance = 0.25,
                dash_length = 0,
                gap_length = 0,
            },
            candidate = {
                color = "#9CA5B880",
                width = 0.035,
                head_length = 0.17,
                head_sweep = math.pi / 4,
                source_clearance = 0.20,
                target_clearance = 0.25,
                dash_length = 0.14,
                gap_length = 0.12,
            },
        },
    },
    appearance = {
        channels_in_states = { "open" },
        channels = {
            l1 = {
                disconnected = "uop_led_l1_disconnected",
                inactive = "uop_led_l1_connected",
                starved = "uop_led_l1_connected",
                emergency = "uop_led_l1_active",
                nominal = "uop_led_l1_active",
            },
            l2 = {
                disconnected = "uop_led_l2_disconnected",
                inactive = "uop_led_l2_connected",
                starved = "uop_led_l2_connected",
                emergency = "uop_led_l2_active",
                nominal = "uop_led_l2_active",
            },
            l3 = {
                disconnected = "uop_led_l3_disconnected",
                inactive = "uop_led_l3_connected",
                starved = "uop_led_l3_connected",
                emergency = "uop_led_l3_active",
                nominal = "uop_led_l3_active",
            },
        },
    },
    category = "power",
    examine = {
        flavor = "A flush metal plate in the deck, with a round removable cap "
            .. "over one recessed socket. Under the cap, a red, a yellow and a "
            .. "blue lamp report the power layer of that color beneath the "
            .. "floor: dark for no cable, dim for connected, bright for active. "
            .. "With the cap off, green arrows show powered connections, "
            .. "amber arrows show unpowered connections, and faint dashed "
            .. "arrows show reachable alternatives.",
    },
}
