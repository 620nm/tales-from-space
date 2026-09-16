local pipe_paints = require("@lib/pipe_paints")
local pipe_thermal = require("@lib/thermal")

local function policy(visible: boolean, accessible: boolean)
    return { appearance = visible, picking = visible, disclosure = visible,
        access = accessible, installation = accessible }
end

local function controls(visible: boolean, open_occupant_sprite: string?)
    local result = { { id = "support", descendant = "support", default = "closed",
        states = { { id = "closed", policy = policy(visible, false) } } } }
    for _, network in ipairs({ "power", "pipe" }) do
        table.insert(result, { id = network, descendant = network, default = "closed",
            states = {
                { id = "closed", policy = policy(visible, false) },
                { id = "open", policy = policy(true, not visible), occupant_sprite = open_occupant_sprite },
            } })
    end
    return result
end

local function barrier_controls()
    local result = controls(false)
    for _, control in ipairs(result) do
        control.states = { control.states[1] }
    end
    return result
end

local function thermal(capacity: number, conductivity: number, emissivity: number)
    return { capacity_j_per_k = capacity, conductivity = conductivity, emissivity = emissivity }
end

local function shapes(prefix: string, channels: {string}, cable: boolean)
    local result: {[string]: {[number]: string}} = {}
    for _, channel in ipairs(channels) do
        local channel_shapes: {[number]: string} = {}
        for mask = 0, 15 do
            channel_shapes[mask] = prefix .. "_" .. channel .. "_" .. (if cable and mask == 0 then "none" else tostring(mask))
        end
        result[channel] = channel_shapes
    end
    return result
end

local function port_shapes(channels: {string})
    local result: {[string]: {[string]: {[number]: string}}} = {}
    for _, channel in ipairs(channels) do
        local states: {[string]: {[number]: string}} = {}
        for _, state in ipairs({ "connected", "exposed", "half" }) do
            local sprites: {[number]: string} = {}
            local family = if state == "connected" then "intact" else state
            for _, direction in ipairs({ 1, 2, 4, 8 }) do
                sprites[direction] = "pipe_" .. family .. "_" .. channel .. "_" .. tostring(direction)
            end
            states[state] = sprites
        end
        result[channel] = states
    end
    return result
end

local paints = {}
for _, paint in ipairs(pipe_paints.colors) do
    local links = { paint.name, "omni" }
    if paint.name == "omni" then
        links = {}
        for _, other in ipairs(pipe_paints.colors) do table.insert(links, other.name) end
    end
    table.insert(paints, { id = paint.name, color = paint.hex,
        connects_to = links, connects_unpainted = true })
end

local power_channels = { "l1", "l2", "l3" }
local pipe_channels = { "l1", "l2", "l3", "l4", "l5" }
local channel_paints: {[string]: string} = {}
for index, channel in ipairs(pipe_channels) do
    channel_paints[channel] = assert(pipe_paints.defaults[index])
end
local supported = { substrate_support = true, any_component = { "station_base", "catwalk" } }

local construction_components = { "station_base", "floor_tiles", "grid_cover", "reinforcement",
    "lattice", "catwalk", "wall", "reinforced_wall" }

return {
    layers = {
        { id = "world" },
        { id = "substrate", parent = "world" },
        { id = "support", parent = "cover" },
        { id = "cover", parent = "world" },
        { id = "infrastructure", parent = "cover" },
        { id = "power", parent = "infrastructure" },
        { id = "pipe", parent = "infrastructure" },
        { id = "matter_ground", parent = "world" },
        { id = "fixture", parent = "world" },
        { id = "item", parent = "world" },
        { id = "lying_mob", parent = "world" },
        { id = "standing_mob", parent = "world" },
        { id = "overhead_entities", parent = "world" },
        { id = "gas_haze", parent = "world" },
        { id = "effects", parent = "world" },
    },
    components = {
        { id = "space", label = "space", layer = "substrate", sprite = "space", substrate = { vacuum_boundary = true }, physical = { ambient = 0.06 } },
        { id = "ground", label = "ground", layer = "substrate", sprite = "ground", substrate = { vacuum_boundary = false },
            physical = { ambient = 0, support = true, thermal = thermal(20000, 0.02, 0.5) } },
        { id = "station_base", occludes_substrate = true, label = "plating", layer = "support", sprite = "plating",
            physical = { ambient = 0.10, support = true, substrate_seal = true, thermal = thermal(62500, 0.025, 0.5) } },
        { id = "floor_tiles", label = "floor", layer = "cover", sprite = "floor", cover = controls(false, "open_floor"),
            physical = { thermal = thermal(20000, 0.02, 0.5) } },
        { id = "grid_cover", label = "open grid floor", layer = "cover", sprite = "open_floor", cover = controls(true),
            physical = { thermal = thermal(20000, 0.02, 0.5) } },
        { id = "reinforcement", label = "reinforced floor", layer = "cover", sprite = "reinforced_floor", cover = controls(false, "open_floor"),
            physical = { thermal = thermal(62500, 0.01, 0.03) } },
        { id = "lattice", label = "lattice", layer = "support", sprite = "lattice-0", physical = { support = true } },
        { id = "catwalk", label = "catwalk", layer = "support", sprite = "catwalk-0", physical = { support = true } },
        { id = "wall", occludes_substrate = true, label = "wall", layer = "cover", sprite = "wall", cover = barrier_controls(),
            physical = { ambient = 0, support = true, substrate_seal = true, movement_blocking = true,
                gas_blocking = true, opaque = true, thermal = thermal(62500, 0, 0.5) } },
        { id = "reinforced_wall", occludes_substrate = true, label = "reinforced wall", layer = "cover", sprite = "reinforced_wall", cover = barrier_controls(),
            physical = { ambient = 0, support = true, substrate_seal = true, movement_blocking = true,
                gas_blocking = true, opaque = true, thermal = thermal(312500, 0, 0.03) } },
    },
    networks = {
        { id = "power", label = "power cable", layer = "power", channels = power_channels, channel_preferences = { "l2", "l1", "l3" },
            solver = "energy", placement = supported, continuing = supported,
            kinds = { { id = "cable", paintable = true, allowed_channels = power_channels, connects_to_kinds = { "cable" }, connectivity = 15, shapes = {}, shapes_by_channel = shapes("cable", power_channels, true) } } },
        { id = "pipe", label = "pipe", layer = "pipe", channels = pipe_channels, channel_preferences = { "l3", "l2", "l4", "l1", "l5" },
            solver = "matter", paints = paints, port_shapes = port_shapes(pipe_channels),
            channel_paints = channel_paints,
            kinds = { { id = "standard", paintable = true, allowed_channels = pipe_channels, connects_to_kinds = { "standard" }, connectivity = 15, shapes = {}, shapes_by_channel = shapes("pipe", pipe_channels, false) },
                { id = "he_pipe", paintable = false, allowed_channels = { "l2", "l3", "l4" }, connects_to_kinds = { "he_pipe" },
                    color = "#404040", connectivity = 15, shapes = {},
                    conducts = { coefficient = pipe_thermal.he_coefficient, min_delta_k = pipe_thermal.he_deadband_k },
                    shapes_by_channel = shapes("he_pipe", { "l2", "l3", "l4" }, false) } } },
    },
    presets = {
        { id = "bare", label = "Bare Substrate", replace_components = construction_components, components = {} },
        { id = "plating", label = "Station Base", replace_components = construction_components, components = { { component = "station_base" } } },
        { id = "floor", label = "Ordinary Floor", replace_components = construction_components, components = { { component = "station_base" }, { component = "floor_tiles" } } },
        { id = "grid", label = "Grid Floor", replace_components = construction_components, components = { { component = "station_base" }, { component = "grid_cover" } } },
        { id = "reinforced_floor", label = "Reinforced Floor", replace_components = construction_components, components = { { component = "station_base" }, { component = "reinforcement" } } },
        { id = "reinforced_floor_exposed", label = "Reinforced Floor, Exposed", replace_components = construction_components, components = { { component = "station_base" },
            { component = "reinforcement", controls = { power = "open", pipe = "open" } } } },
        { id = "lattice", label = "Lattice", replace_components = construction_components, components = { { component = "lattice" } } },
        { id = "catwalk", label = "Catwalk", replace_components = construction_components, components = { { component = "catwalk" } } },
        { id = "wall", label = "Wall", replace_components = construction_components, components = { { component = "station_base" }, { component = "wall" } } },
        { id = "reinforced_wall", label = "Reinforced Wall", replace_components = construction_components, components = { { component = "station_base" }, { component = "reinforced_wall" } } },
    },
    transitions = {
        { id = "remove_catwalk", remove_components = { "catwalk" }, remove_unsupported_networks = { "power" } },
    },
}
