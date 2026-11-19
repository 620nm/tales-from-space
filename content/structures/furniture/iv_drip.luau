-- A loose, unpowered stand for an IV vessel and line.
-- tg: code/game/machinery/iv_drip.dm:14-21.
local ui_label = require("@lib/ui_label")

return {
    id = "iv_drip",
    entity_class = "installed",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.iv_drip.name",
    name = "IV drip",
    sprite = "iv_drip",
    examine = {
        flavor = "An unpowered stand holds a docked vessel for an IV line.",
    },
    dense = false,
    loose = true,
    states = {
        "iv_drip_injectidle",
        "iv_drip_injecting",
        "iv_drip_donateidle",
        "iv_drip_donating",
    },
    state_sprites = {
        iv_drip_injectidle = "iv_drip_injectidle",
        iv_drip_injecting = "iv_drip_injecting",
        iv_drip_donateidle = "iv_drip_donateidle",
        iv_drip_donating = "iv_drip_donating",
    },
    motion_response = {
        mass = 5.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.35,
        public_contacts = true,
    },
    chem = {
        device = "slot",
    },
    ui = {
        modules = { "dock", "actions" },
        actions = {
            { key = "disconnect", label = ui_label.pack("lunatic/tfs:action.iv_drip.disconnect") },
            { key = "toggle_mode", label = ui_label.pack("lunatic/tfs:action.iv_drip.toggle_mode") },
            { key = "flow_down", label = ui_label.pack("lunatic/tfs:action.iv_drip.flow_down") },
            { key = "flow_up", label = ui_label.pack("lunatic/tfs:action.iv_drip.flow_up") },
            { key = "flow_max", label = ui_label.pack("lunatic/tfs:action.iv_drip.flow_max") },
            { key = "flow_off", label = ui_label.pack("lunatic/tfs:action.iv_drip.flow_off") },
            {
                key = "rate",
                label = ui_label.pack("lunatic/tfs:action.iv_drip.rate"),
                input = {
                    label = ui_label.pack("lunatic/tfs:action.iv_drip.rate_value"),
                    max_length = 8,
                },
            },
        },
    },
    actions = {
        {
            id = "deconstruct",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:action.iv_drip.deconstruct",
            held = { fact = "held.proto", value = "wrench" },
            uses_held = true,
        },
    },
    script = "iv_drip",
}
