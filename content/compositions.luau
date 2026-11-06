local decal_paints = require("@lib/decal_paints")
local load_classes = require("@lib/load_classes")
local pipe_paints = require("@lib/pipe_paints")
local pipe_thermal = require("@lib/thermal")

local function policy(visible: boolean, accessible: boolean)
    return { appearance = visible, picking = visible, disclosure = visible,
        access = accessible, installation = accessible }
end

local function controls(visible: boolean, open_occupant_sprite: string?, open_occupant_layer: string?)
    local result = { { id = "support", descendant = "support", default = "closed",
        states = { { id = "closed", policy = policy(visible, false) } } } }
    for _, network in ipairs({ "power", "pipe" }) do
        table.insert(result, { id = network, descendant = network, default = "closed",
            states = {
                { id = "closed", policy = policy(visible, false) },
                { id = "open", policy = policy(true, not visible), occupant_sprite = open_occupant_sprite,
                    occupant_layer = open_occupant_layer },
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

-- One picture for every shape of a kind, per channel: an adapter is a
-- fixture, not a run that bends with its neighbors.
local function uniform_shapes(sprite_of: (string) -> string, channels: {string})
    local result: {[string]: {[number]: string}} = {}
    for _, channel in ipairs(channels) do
        local channel_shapes: {[number]: string} = {}
        for mask = 0, 15 do
            channel_shapes[mask] = sprite_of(channel)
        end
        result[channel] = channel_shapes
    end
    return result
end

-- The mouth caps tg draws over a device's ports, joined or not
-- (filter.dm:51, vent_pump.dm:190). A device names one as `atmos.mouth_cap`.
local mouth_cap_families = { "inline", "vent", "scrub", "inje", "intake" }

local function port_shapes(channels: {string})
    local result: {[string]: any} = {}
    for index, channel in ipairs(channels) do
        local states: {[string]: any} = {}
        for _, state in ipairs({ "connected", "exposed", "half" }) do
            local sprites: {[number]: string} = {}
            local family = if state == "connected" then "intact" else state
            for _, direction in ipairs({ 1, 2, 4, 8 }) do
                sprites[direction] = "pipe_" .. family .. "_" .. channel .. "_" .. tostring(direction)
            end
            states[state] = sprites
        end
        -- PIPING_LAYER_SHIFT, five pixels per layer off the middle one
        -- (atmos_helpers.dm): a body lies on the run it stands in.
        local shift = (index - 3) * 5
        states.body_offset = { shift, shift }
        local caps: {[string]: {[number]: string}} = {}
        for _, family in ipairs(mouth_cap_families) do
            local sprites: {[number]: string} = {}
            for _, direction in ipairs({ 1, 2, 4, 8 }) do
                sprites[direction] = "pipe_cap_" .. family .. "_" .. channel .. "_" .. tostring(direction)
            end
            caps[family] = sprites
        end
        states.caps = caps
        result[channel] = states
    end
    return result
end

-- Decks a decal may be painted on. tg attaches its decal element to any
-- /turf/open/floor, plating included, and plating is what most of this
-- station is. Lattice, catwalk and the open grid cover are gratings you
-- see the subfloor through -- paint has nothing to sit on -- and a wall
-- is not a deck.
local decal_decks = { "station_base", "floor_tiles", "reinforcement" }

type CardinalArt = { n: string, e: string, s: string, w: string }
type DiagonalArt = { ne: string, se: string, sw: string, nw: string }

-- A trim family is seventeen sprite names off one prefix and all
-- seventeen follow `assets/sprites/11-decals.ron`'s naming exactly.
-- Writing four families out by hand would be four chances to typo a
-- direction nobody reads.
local function cardinal_art(prefix: string, suffix: string): CardinalArt
    return { n = prefix .. suffix .. "_n", e = prefix .. suffix .. "_e",
        s = prefix .. suffix .. "_s", w = prefix .. suffix .. "_w" }
end

local function diagonal_art(prefix: string, suffix: string): DiagonalArt
    return { ne = prefix .. suffix .. "_ne", se = prefix .. suffix .. "_se",
        sw = prefix .. suffix .. "_sw", nw = prefix .. suffix .. "_nw" }
end

local function trim_decal(id: string, prefix: string, colored: boolean, opacity: number)
    return { id = id, layer = "decal", form = "trim", colored = colored,
        opacity = opacity, on = decal_decks,
        edge = cardinal_art(prefix, "_edge"), bend = diagonal_art(prefix, "_bend"),
        cap = cardinal_art(prefix, "_cap"), box = prefix .. "_box",
        corner = diagonal_art(prefix, "_corner") }
end

local function mark_decal(id: string, sprite: string?, facing: CardinalArt?, colored: boolean?)
    return { id = id, layer = "decal", form = "mark", colored = colored or false,
        opacity = decal_paints.mark_opacity, on = decal_decks,
        sprite = sprite, facing = facing }
end

local decals: {any} = {
    trim_decal("trim", "decal_trim", true, decal_paints.trim_opacity),
    trim_decal("trim_fill", "decal_trim_fill", true, decal_paints.trim_opacity),
    -- The stripes carry tg's own yellow-on-black hatching and its flat
    -- red and white, so they take no paint and no tint.
    trim_decal("hazard_line", "decal_hazard", false, decal_paints.mark_opacity),
    trim_decal("hazard_line_red", "decal_hazard_red", false, decal_paints.mark_opacity),
    trim_decal("hazard_line_white", "decal_hazard_white", false, decal_paints.mark_opacity),
    mark_decal("mark_delivery", "decal_mark_delivery", nil),
    mark_decal("mark_bot", "decal_mark_bot", nil),
    mark_decal("mark_loading", nil, cardinal_art("decal_mark_loading", "")),
    mark_decal("mark_arrow", nil, cardinal_art("decal_mark_arrow", "")),
    mark_decal("mark_caution", nil, cardinal_art("decal_mark_caution", "")),
    mark_decal("mark_stand_clear", nil, cardinal_art("decal_mark_stand_clear", "")),
    -- What a wound leaves: tg's splatter art (blood.dmi `gibbl1`, the
    -- first of /obj/effect/decal/cleanable/blood/splatter's five,
    -- blood.dm:271-272) in tg's deck-pool red, drawn four ways round
    -- so the wound handler can aim the spray off a blast. Colored,
    -- because the art is a grayscale mask and the red arrives as
    -- paint — and the paint is the `blood` entry below, since a
    -- script may only place a DECLARED paint (`free.play` is false).
    -- No crew tool offers this decal: blood on the deck means a
    -- wound, never a dial.
    mark_decal("blood", nil, cardinal_art("blood_splatter", ""), true),
}

-- The quadrant family paints halves rather than lines, so three sides of
-- it IS the whole tile: one sprite serves every cap and the box.
local tiling = trim_decal("tile", "decal_tile", true, decal_paints.trim_opacity)
tiling.box = "decal_tile_full"
tiling.cap = { n = "decal_tile_full", e = "decal_tile_full",
    s = "decal_tile_full", w = "decal_tile_full" }
table.insert(decals, 3, tiling)

local decal_palette = {}
for _, paint in ipairs(decal_paints.colors) do
    table.insert(decal_palette, { id = paint.id, color = paint.hex })
end
-- tg's deck-pool red, BLOOD_COLOR_RED (code/__DEFINES/colors.dm:225,
-- worn by /obj/effect/decal/cleanable/blood, blood.dm:9). Declared
-- HERE rather than in `lib/decal_paints.luau`: that roster is tg's
-- twelve tile paints verbatim and the painter's dial enumerates every
-- one of them (tests/decals/decal_painter_test.luau pins twelve), so a
-- thirteenth would hand the crew a blood-red paint. This one is the
-- wound handler's alone.
table.insert(decal_palette, { id = "blood", color = "#AA1010" })

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
    "lattice", "catwalk", "wall", "reinforced_wall", "rock",
    "glass_floor", "reinforced_glass_floor", "lead_glass_floor", "reinforced_lead_glass_floor" }

-- Floor windows over an open substrate (tg /turf/open/floor/glass, glass.dm:2-85, plus
-- first-party radiologically shielded lead-glass variants): they hold a body and the air
-- (support, seal), show the level below, and show runs without tool access
-- (UNDERFLOOR_VISIBLE, glass.dm:8). Thermal is floor.dm:17-18 with the pack's floor
-- emissivity; ambient is the plating's, which a glass floor replaces.
-- Light passes a floor window as sight does (undeclared `light_transmission`); lead
-- glass tints transmitted light warm steeped-tea/amber through high-lead-oxide shielding glass.
local LEAD_GLASS_LIGHT = { r = 1.0, g = 0.82, b = 0.38 }

local function glass_floor(id: string, label: string, light_transmission: { r: number, g: number, b: number }?)
    return { id = id, label = label, layer = "cover", sprite = id .. "-0", cover = controls(true),
        physical = { ambient = 0.10, support = true, receives_gravity = true, substrate_seal = true,
            light_transmission = light_transmission, thermal = thermal(20000, 0.02, 0.5) } }
end

local composition_declaration: { [string]: any } = {
    layers = {
        { id = "world" },
        { id = "substrate", parent = "world" },
        -- A tile's ground material (content/terrain.luau `face`): over the
        -- substrate it stands on and under cover, decals, residue and matter.
        { id = "ground_face", parent = "world" },
        { id = "support", parent = "cover" },
        { id = "cover", parent = "world" },
        { id = "exposed_cover", parent = "cover" },
        { id = "infrastructure", parent = "cover" },
        { id = "pipe", parent = "infrastructure" },
        { id = "power", parent = "infrastructure" },
        -- Painted-on floor markings. A child of `world` and NOT of
        -- `cover`, deliberately: siblings keep declaration order and a
        -- descendant draws before its parent's occupants, so a `cover`
        -- child would slide UNDER the floor tile it is painted on. Here
        -- it draws over the whole cover subtree and under anything lying
        -- on the deck. Being outside `cover` also means no cover control
        -- can reach it, which is what we want: prying a tile destroys
        -- the paint on it rather than hiding it.
        { id = "decal", parent = "world" },
        -- Settled dust: over the paint and under the spills, so a blast
        -- marks the deck without hiding what is standing on it (the
        -- engine's docs/physics/residue.md; content/residue_appearances.luau).
        { id = "residue", parent = "world" },
        { id = "matter_ground", parent = "world" },
        { id = "fixture", parent = "world" },
        -- Closets, crates and freezers draw under items: tg seats an open
        -- closet at BELOW_OBJ_LAYER (`closets.dm:249`, `layers.dm:239`).
        -- A prototype has one static layer, and tg's closed `OBJ_LAYER`
        -- equals `item`'s, so "under" is the honest choice for both states.
        { id = "low_object", parent = "world" },
        { id = "item", parent = "world" },
        -- Large loose things -- vessels, unbolted frames --
        -- draw over items. tg's own seat for a canister is above items
        -- (ABOVE_OBJ_LAYER over OBJ_LAYER over BELOW_OBJ_LAYER,
        -- layers.dm:239-244, portable_atmospherics.dm:10); the uniform
        -- rule for the whole class is this station's own.
        { id = "large_object", parent = "world" },
        { id = "lying_mob", parent = "world" },
        { id = "standing_mob", parent = "world" },
        { id = "overhead_entities", parent = "world" },
        { id = "gas_haze", parent = "world" },
        -- Flames draw over the haze and under effects: they are emissive,
        -- so everything above them on the tile is lit by them.
        { id = "matter_flame", parent = "world" },
        { id = "effects", parent = "world" },
    },
    components = {
        { id = "space", label = "space", layer = "substrate", sprite = "space", substrate = { vacuum_boundary = true }, physical = { ambient = 0.06 } },
        { id = "ground", label = "ground", layer = "substrate", sprite = "ground", substrate = { vacuum_boundary = false },
            physical = { ambient = 0, support = true, thermal = thermal(20000, 0.02, 0.5) } },
        -- tg /turf/open/misc/asteroid (asteroid.dm:5-14): a natural floor under mined rock. It holds a body
        -- and receives the station field; like `ground` it is no vacuum boundary. Thermal: tg
        -- /turf/open/misc heat_capacity and thermal_conductivity (misc.dm:20-21), the pack's emissivity.
        { id = "rock_floor", label = "rock floor", layer = "substrate", sprite = "rock_floor", substrate = { vacuum_boundary = false },
            physical = { ambient = 0, support = true, receives_gravity = true, thermal = thermal(20000, 0.02, 0.5) } },
        -- tg /turf/open/misc/ice (ice.dm:1-5): the floor only frozen water's profile names, drawn as
        -- tg's unsmoothed `ice_turf-0`. Like `ground` it holds a body and is no vacuum boundary.
        -- Thermal: tg /turf/open/misc (misc.dm:20-21) verbatim, the pack's emissivity (the engine's
        -- docs/PORTING.md rules 3-4); tg's ice temperature (ice.dm:9) is not a floor's to carry.
        { id = "ice_floor", label = "ice sheet", layer = "substrate", sprite = "ice_floor-0", substrate = { vacuum_boundary = false },
            physical = { ambient = 0, support = true, thermal = thermal(20000, 0.02, 0.5) } },
        { id = "station_base", occludes_substrate = true, label = "plating", layer = "support", sprite = "plating",
            physical = { ambient = 0.10, support = true, receives_gravity = true, substrate_seal = true, thermal = thermal(62500, 0.025, 0.5) } },
        { id = "floor_tiles", label = "floor", layer = "cover", sprite = "floor", cover = controls(false, "open_floor", "exposed_cover"),
            physical = { thermal = thermal(20000, 0.02, 0.5) } },
        { id = "grid_cover", label = "open grid floor", layer = "cover", sprite = "open_floor", cover = controls(true),
            physical = { thermal = thermal(20000, 0.02, 0.5) } },
        -- No open occupant art: the rods stay in place when exposed, so the
        -- cover keeps its own sprite with the runs disclosed over it.
        { id = "reinforcement", label = "reinforced floor", layer = "cover", sprite = "reinforced_floor", cover = controls(false, nil, "exposed_cover"),
            physical = { thermal = thermal(62500, 0.01, 0.03) } },
        { id = "lattice", label = "lattice", layer = "support", sprite = "lattice-0", physical = { support = true, handhold = true } },
        { id = "catwalk", label = "catwalk", layer = "support", sprite = "catwalk-0", physical = { support = true, handhold = true } },
        { id = "wall", occludes_substrate = true, label = "wall", layer = "cover", sprite = "wall", cover = barrier_controls(),
            physical = { ambient = 0, support = true, receives_gravity = true, substrate_seal = true, movement_blocking = true,
                gas_blocking = true, opaque = true, thermal = thermal(62500, 0, 0.5) } },
        { id = "reinforced_wall", occludes_substrate = true, label = "reinforced wall", layer = "cover", sprite = "reinforced_wall", cover = barrier_controls(),
            physical = { ambient = 0, support = true, receives_gravity = true, substrate_seal = true, movement_blocking = true,
                gas_blocking = true, opaque = true, thermal = thermal(312500, 0, 0.03) } },
        -- tg /turf/closed/mineral: opaque, dense (minerals.dm:6-51, :15-16), airtight as a closed turf
        -- (_closed.dm:8 `blocks_air`). No `thermal`: it sets no heat_capacity, so INFINITY
        -- (LINDA_turf_tile.dm:5), unrepresentable; the tile keeps its substrate's.
        -- `receives_gravity` matches the walls and is unobservable: no step enters blocking rock, and
        -- a fall neither starts onto it nor lands in it (the engine's
        -- crates/lunatic-server/src/sim/movement/levels/level_body.rs:resolve_fall_step).
        { id = "rock", occludes_substrate = true, label = "rock", layer = "cover", sprite = "rock-0", cover = barrier_controls(),
            physical = { ambient = 0, support = true, receives_gravity = true, substrate_seal = true, movement_blocking = true,
                gas_blocking = true, opaque = true } },
        glass_floor("glass_floor", "glass floor"),
        glass_floor("reinforced_glass_floor", "reinforced glass floor"),
        glass_floor("lead_glass_floor", "lead glass floor", LEAD_GLASS_LIGHT),
        glass_floor("reinforced_lead_glass_floor", "reinforced lead glass floor", LEAD_GLASS_LIGHT),
    },
    networks = {
        { id = "power", label = "power cable", layer = "power", channels = power_channels, channel_preferences = { "l2", "l1", "l3" },
            solver = "energy", placement = supported, continuing = supported,
            -- What a panel switches whole (lib/load_classes.luau).
            load_classes = load_classes.power, default_load_class = load_classes.power_default,
            kinds = { { id = "cable", paintable = true, allowed_channels = power_channels, connects_to_kinds = { "cable", "hub" }, connectivity = 15, shapes = {}, shapes_by_channel = shapes("cable", power_channels, true) },
                -- tg's multi-z cable hub (power/multiz.dm:1-12): the one run member
                -- that joins the hub stacked directly above or below it. Laterally
                -- it is cable; one channel per hub, a divergence from tg's all-layer hub.
                { id = "hub", paintable = false, allowed_channels = power_channels, connects_to_kinds = { "hub", "cable" }, cross_level_adapter = true,
                    connectivity = 15, shapes = {}, shapes_by_channel = uniform_shapes(function(_channel: string) return "cable_hub" end, power_channels) } } },
        { id = "pipe", label = "pipe", layer = "pipe", channels = pipe_channels, channel_preferences = { "l3", "l2", "l4", "l1", "l5" },
            solver = "matter", paints = paints, port_shapes = port_shapes(pipe_channels),
            channel_paints = channel_paints,
            kinds = { { id = "standard", paintable = true, allowed_channels = pipe_channels, connects_to_kinds = { "standard", "adapter" }, connectivity = 15, shapes = {}, shapes_by_channel = shapes("pipe", pipe_channels, false) },
                -- tg's multi-deck pipe adapter (pipes/multiz.dm:2-60, `paintable = FALSE`):
                -- joins the adapter stacked directly above or below it. Laterally it
                -- joins every side like pipe, where tg's mouths only its `dir` (multiz.dm:8-9).
                { id = "adapter", paintable = false, allowed_channels = pipe_channels, connects_to_kinds = { "adapter", "standard" }, cross_level_adapter = true,
                    connectivity = 15, shapes = {}, shapes_by_channel = uniform_shapes(function(channel: string) return "pipe_adapter_" .. channel end, pipe_channels) },
                { id = "radiator_pipe", paintable = false, allowed_channels = { "l2", "l3", "l4" }, connects_to_kinds = { "radiator_pipe" },
                    color = "#404040", connectivity = 15, shapes = {},
                    conducts = { coefficient = pipe_thermal.radiator_coefficient, min_delta_k = pipe_thermal.radiator_deadband_k },
                    shapes_by_channel = shapes("radiator_pipe", { "l2", "l3", "l4" }, false) } } },
    },
    decals = decals,
    decal_colors = {
        paints = decal_palette,
        -- The map and the editor may name a raw color; an in-game tool
        -- may not. A shift's paint is the station's paint.
        free = { map = true, play = false },
    },
    presets = {
        -- `bare` and `rock` write the `inherit` substrate (the profile substrate
        -- at or below ground, open sky above), so painting either over an `open`
        -- hole at or below ground closes it. `open` cuts a hole on any level
        -- but the lowest, which refuses it.
        { id = "bare", label = "Bare Substrate", substrate = "inherit", replace_components = construction_components, components = {} },
        { id = "open", label = "Open (hole)", substrate = "open", replace_components = construction_components, components = {} },
        { id = "plating", label = "Station Base", replace_components = construction_components, components = { { component = "station_base" } } },
        { id = "floor", label = "Tiled Floor", replace_components = construction_components, components = { { component = "station_base" }, { component = "floor_tiles" } } },
        { id = "floor_exposed", label = "Tiled Floor, Exposed", variant_of = "floor", replace_components = construction_components, components = { { component = "station_base" },
            { component = "floor_tiles", controls = { power = "open", pipe = "open" } } } },
        { id = "grid", label = "Grid Floor", replace_components = construction_components, components = { { component = "station_base" }, { component = "grid_cover" } } },
        { id = "reinforced_floor", label = "Reinforced Floor", replace_components = construction_components, components = { { component = "station_base" }, { component = "reinforcement" } } },
        { id = "reinforced_floor_exposed", label = "Reinforced Floor, Exposed", variant_of = "reinforced_floor", replace_components = construction_components, components = { { component = "station_base" },
            { component = "reinforcement", controls = { power = "open", pipe = "open" } } } },
        { id = "lattice", label = "Lattice", replace_components = construction_components, components = { { component = "lattice" } } },
        { id = "catwalk", label = "Catwalk", replace_components = construction_components, components = { { component = "catwalk" } } },
        { id = "wall", label = "Wall", replace_components = construction_components, components = { { component = "station_base" }, { component = "wall" } } },
        { id = "reinforced_wall", label = "Reinforced Wall", replace_components = construction_components, components = { { component = "station_base" }, { component = "reinforced_wall" } } },
        { id = "rock", label = "Rock", substrate = "inherit", replace_components = construction_components, components = { { component = "rock" } } },
        { id = "rock_floor", label = "Rock Floor", substrate = "rock_floor", replace_components = construction_components, components = {} },
        { id = "glass_floor", label = "Glass Floor", substrate = "open", replace_components = construction_components,
            components = { { component = "glass_floor" } } },
        { id = "reinforced_glass_floor", label = "Reinforced Glass Floor", substrate = "open", replace_components = construction_components,
            components = { { component = "reinforced_glass_floor" } } },
        { id = "lead_glass_floor", label = "Lead Glass Floor", substrate = "open", replace_components = construction_components,
            components = { { component = "lead_glass_floor" } } },
        { id = "reinforced_lead_glass_floor", label = "Reinforced Lead Glass Floor", substrate = "open", replace_components = construction_components,
            components = { { component = "reinforced_lead_glass_floor" } } },
    },
    transitions = {
        { id = "remove_catwalk", remove_components = { "catwalk" }, remove_unsupported_networks = { "power" } },
    },
}

return composition_declaration
