-- The shelf, in tg's own order and words (`GLOB.atmos_pipe_recipes`,
-- code/_globalvars/lists/pipe_recipes.dm), as far as this pack has
-- entries for it. `structure` names what stands up; the one row without
-- one is pipe itself, which is not a structure at all but a length in
-- the grid under the deck.
export type Recipe = {
    label: string,
    item: string,
    icon: string,
    group: string,
    structure: string?,
    network_kind: string?,
    fixed_layer: boolean?,
    paints: boolean?,
}

local RECIPES: { Recipe } = {
    { label = "Pipe", item = "pipe", icon = "pipe", group = "Pipes", network_kind = "standard" },
    -- tg's "Multi-Deck Adapter" (pipe_recipes.dm:7): laid in the run like
    -- pipe, one per piping layer, and unpainted (multiz.dm:17).
    {
        label = "Multi-Deck Adapter",
        item = "pipe_adapter",
        icon = "pipe_adapter_loose",
        group = "Pipes",
        network_kind = "adapter",
        paints = false,
    },
    {
        label = "Manual Valve",
        item = "manual_valve_fitting",
        structure = "manual_valve",
        icon = "manual_valve_loose",
        group = "Binary Devices",
    },
    {
        label = "Digital Valve",
        item = "digital_valve_fitting",
        structure = "digital_valve",
        icon = "digital_valve_loose",
        group = "Binary Devices",
    },
    {
        label = "Pump",
        item = "pump_fitting",
        structure = "pump",
        icon = "pump_loose",
        group = "Binary Devices",
    },
    {
        label = "Volume Pump",
        item = "volume_pump_fitting",
        structure = "volume_pump",
        icon = "volume_pump_loose",
        group = "Binary Devices",
    },
    {
        label = "Passive Gate",
        item = "passive_gate_fitting",
        structure = "passive_gate",
        icon = "passive_gate_loose",
        group = "Binary Devices",
    },
    {
        label = "Pressure Valve",
        item = "pressure_valve_fitting",
        structure = "pressure_valve",
        icon = "pressure_valve_loose",
        group = "Binary Devices",
    },
    {
        label = "Filter",
        item = "filter_fitting",
        structure = "filter",
        icon = "filter_fitting",
        group = "Trinary Devices",
    },
    {
        label = "Filter (flipped)",
        item = "filter_flipped_fitting",
        structure = "filter.flipped",
        icon = "filter_fitting",
        group = "Trinary Devices",
    },
    {
        label = "Mixer",
        item = "mixer_fitting",
        structure = "mixer",
        icon = "mixer_fitting",
        group = "Trinary Devices",
    },
    {
        label = "Mixer (flipped)",
        item = "mixer_flipped_fitting",
        structure = "mixer.flipped",
        icon = "mixer_fitting",
        group = "Trinary Devices",
    },
    {
        label = "Connector",
        item = "connector_port_fitting",
        structure = "connector_port",
        icon = "connector_port_loose",
        group = "Fittings & Adapters",
        fixed_layer = true,
    },
    {
        label = "Meter",
        item = "pipe_meter",
        structure = "meter",
        icon = "pipe_meter",
        group = "Fittings & Adapters",
    },
    {
        label = "Layer Adapter",
        item = "layer_adapter_fitting",
        structure = "layer_adapter",
        icon = "layer_adapter_loose",
        group = "Fittings & Adapters",
        fixed_layer = true,
    },
    {
        label = "Color Adapter",
        item = "color_adapter_fitting",
        structure = "color_adapter",
        icon = "color_adapter_loose",
        group = "Fittings & Adapters",
    },
    {
        label = "Temperature Gate",
        item = "temperature_gate_fitting",
        structure = "temperature_gate",
        icon = "temperature_gate_loose",
        group = "Thermal Devices",
    },
    {
        label = "Temperature Pump",
        item = "temperature_pump_fitting",
        structure = "temperature_pump",
        icon = "temperature_pump_loose",
        group = "Thermal Devices",
    },
    {
        label = "Heat Exchanger",
        item = "heat_exchanger_fitting",
        structure = "heat_exchanger",
        icon = "heat_exchanger_loose",
        group = "Thermal Devices",
    },
    -- tg's "Heat Exchange" category, in tg's own words
    -- (`GLOB.atmos_pipe_recipes`, _globalvars/lists/pipe_recipes.dm:29-34).
    -- tg lists "Pipe", "Manifold" and "4-Way Manifold" separately because
    -- each is a different OBJECT there; here a length's shape is derived
    -- from what it joins, so all three are one entry and a manifold is
    -- what you get by running a fourth length into a tee. The plate tg
    -- lists last is already on the shelf above, with the rest of the
    -- thermal kit.
    { label = "Pipe", item = "radiator_pipe", network_kind = "radiator_pipe", icon = "radiator_pipe", group = "Heat Exchange", paints = false },
    {
        label = "Junction",
        item = "radiator_junction_fitting",
        structure = "radiator_junction",
        icon = "radiator_junction_loose",
        group = "Heat Exchange",
    },
    {
        label = "Air Scrubber",
        item = "air_scrubber_fitting",
        structure = "air_scrubber",
        icon = "air_scrubber_loose",
        group = "Room Devices",
    },
    {
        label = "Air Injector",
        item = "air_injector_fitting",
        structure = "air_injector",
        icon = "air_injector_loose",
        group = "Room Devices",
    },
    {
        label = "Bidirectional Vent",
        item = "bidirectional_vent_fitting",
        structure = "bidirectional_vent",
        icon = "bidirectional_vent_loose",
        group = "Room Devices",
        fixed_layer = true,
    },
    {
        label = "Air Vent",
        item = "vent_fitting",
        structure = "vent",
        icon = "vent_loose",
        group = "Room Devices",
    },
    {
        label = "Passive Vent",
        item = "passive_vent_fitting",
        structure = "passive_vent",
        icon = "passive_vent_loose",
        group = "Room Devices",
    },
    {
        label = "Floor Drain",
        item = "floor_drain_fitting",
        structure = "floor_drain",
        icon = "floor_drain",
        group = "Room Devices",
    },
    {
        label = "Sump Pump",
        item = "sump_pump_fitting",
        structure = "sump_pump",
        icon = "sump_pump_off_n",
        group = "Room Devices",
    },
}

return { recipes = RECIPES }
