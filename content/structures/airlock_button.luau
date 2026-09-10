-- A mounted request endpoint; the joined host's guest decides what a press means.
return {
    id = "airlock_button",
    name_label = "lunatic/tfs:entity.airlock_button.name",
    name = "button", sprite = "airlock_button",
    mount = true, script = "airlock_button",
    actions = { {
        id = "press", gesture = "primary", route = "receiver",
        label = "lunatic/tfs:ui.affordance.press",
        held = { fact = "held.present", value = "false" },
    } },
    link = { network_interface = true, role = "endpoint", class = "control_button" },
    appearance = { mounted = {
        north = "airlock_button_n", south = "airlock_button_s",
        east = "airlock_button_e", west = "airlock_button_w",
    } },
    build = {
        on = { "wall", "reinforced_wall" }, with = { airlock_button_fitting = 1 },
        secs = 2.0,
        start = "lunatic/tfs:entity.airlock_button.build.start",
        done = "lunatic/tfs:entity.airlock_button.build.done",
    },
    transitions = { {
        tool = "screwdriver", secs = 2.0, gone = true,
        yields = { airlock_button_fitting = 1 },
        start = "lunatic/tfs:entity.airlock_button.remove.start",
        done = "lunatic/tfs:entity.airlock_button.remove.done",
    } },
}
